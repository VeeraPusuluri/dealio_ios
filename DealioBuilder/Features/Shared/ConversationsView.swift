import SwiftUI

/// Messaging, for all three portals.
///
/// One inbox and one thread screen serve the builder, the CP and the buyer. That
/// is possible because a conversation is between *people*: the backend resolves
/// who the caller is from their token and hands back the conversations they may
/// hold, so nothing here is role-specific except which colour the other person's
/// avatar is. Mirrors Android's `ui/flow/Conversations.kt`.

// MARK: - Reading a conversation's shape

/// The two roles named in a kind, e.g. "builder-cp" → builder and cp.
private func rolesOf(_ kind: String) -> [DealRole] {
    kind.split(separator: "-").compactMap { DealRole(rawValue: String($0)) }
}

/// Who the viewer is talking to, or nil for the group. Derived from the kind
/// rather than sent by the server, because the kind already carries it: a pair
/// names two roles and one of them is you.
func counterpartOf(_ kind: String, viewer: DealRole) -> DealRole? {
    rolesOf(kind).first { $0 != viewer }
}

/// The accent for a conversation row — the other person's colour, navy for a group.
private func accentOf(_ conversation: Conversation, viewer: DealRole) -> Color {
    if conversation.isGroup { return .dealioNavy }
    return counterpartOf(conversation.kind, viewer: viewer)?.color ?? .brandTeal
}

private func initialsOf(_ name: String) -> String {
    let parts = name.split(whereSeparator: { $0 == " " || $0 == "&" }).prefix(2)
    let letters = parts.compactMap { $0.first }.map { String($0).uppercased() }.joined()
    return letters.isEmpty ? "?" : letters
}

/// What the other side is, in a word — the second line of a picker row.
private func kindLabel(_ kind: String, viewer: DealRole) -> String {
    if kind == "group" { return "All three — you, the builder and the buyer" }
    switch counterpartOf(kind, viewer: viewer) {
    case .builder: return "Builder"
    case .cp: return "Channel partner"
    case .customer: return "Customer"
    case nil: return "Conversation"
    }
}

// MARK: - The inbox

@MainActor
final class ConversationsModel: ObservableObject {
    @Published var loading = true
    @Published var error: String?
    @Published var conversations: [Conversation] = []
    /// Everyone the user could talk to — loaded lazily, when "+" is tapped.
    @Published var candidates: [Conversation] = []
    @Published var loadingCandidates = false
    @Published var picking = false
    /// Set once a candidate has been opened, so the screen can navigate to it.
    @Published var opened: Int?

    func load() async {
        loading = conversations.isEmpty
        error = nil
        do { conversations = try await ThreadService.list() }
        catch { self.error = authMessage(error) }
        loading = false
    }

    /// Open the "+" sheet and fetch who is available.
    ///
    /// Fetched on demand rather than alongside the inbox: the roster is derived
    /// from every lead the user has, which is the more expensive of the two
    /// queries and is worth nothing until the sheet is actually open.
    func startPicking() async {
        picking = true
        loadingCandidates = true
        do { candidates = try await ThreadService.candidates() }
        catch { self.error = authMessage(error) }
        loadingCandidates = false
    }

    /// Open (or resume) the picked conversation, then hand its id to the screen.
    func open(key: String) async {
        do {
            let conversation = try await ThreadService.open(key: key)
            picking = false
            opened = conversation.id
        } catch {
            picking = false
            self.error = authMessage(error)
        }
    }
}

/// The conversations screen, complete — list, "+" picker and empty state.
///
/// - `viewer`: whose portal this is, which decides only the avatar colours and
///   which side of a pair counts as "the other person".
/// - `emptyHint`: what to say when there is nothing yet, in this role's terms.
struct ConversationsView: View {
    let viewer: DealRole
    var emptyHint: String = "Start a conversation with anyone on your leads."

    @StateObject private var model = ConversationsModel()
    @State private var route: Int?

    var body: some View {
        Group {
            if model.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.error, model.conversations.isEmpty {
                VStack(spacing: 14) {
                    ErrorBanner(message: error)
                    Button("Try again") { Task { await model.load() } }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        Text(summaryLine)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.dealioTextSecondary)

                        if model.conversations.isEmpty {
                            ContentUnavailableView("No conversations yet",
                                                   systemImage: "bubble.left.and.bubble.right",
                                                   description: Text(emptyHint))
                                .padding(.top, 30)
                        } else {
                            ForEach(model.conversations, id: \.rowID) { conversation in
                                Button {
                                    if let id = conversation.id { route = id }
                                } label: {
                                    ConversationRow(conversation: conversation, viewer: viewer)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                }
                .refreshable { await model.load() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Conversations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await model.startPicking() } } label: {
                    Image(systemName: "plus").fontWeight(.semibold)
                }
                .accessibilityLabel("New conversation")
            }
        }
        // Reload on entry and on every return, so a conversation read on the
        // thread screen comes back without its badge.
        .task { await model.load() }
        .sheet(isPresented: $model.picking) {
            CandidatePicker(
                candidates: model.candidates,
                loading: model.loadingCandidates,
                viewer: viewer
            ) { candidate in
                if let id = candidate.id {
                    model.picking = false
                    route = id
                } else {
                    Task { await model.open(key: candidate.key) }
                }
            }
            .presentationDetents([.large])
        }
        // Opening a candidate lands here once the backend has minted (or found)
        // the row and returned its id.
        .onChange(of: model.opened) { _, id in
            if let id { route = id; model.opened = nil }
        }
        .navigationDestination(item: $route) { id in
            ConversationThreadView(conversationId: id, viewer: viewer)
        }
    }

    private var summaryLine: String {
        let count = model.conversations.count
        let unread = model.conversations.reduce(0) { $0 + $1.unreadCount }
        var line = "\(count) \(count == 1 ? "conversation" : "conversations")"
        if unread > 0 { line += " · \(unread) unread" }
        return line
    }
}

private struct ConversationRow: View {
    let conversation: Conversation
    let viewer: DealRole

    var body: some View {
        let accent = accentOf(conversation, viewer: viewer)
        let unread = conversation.unreadCount > 0
        HStack(spacing: 11) {
            ZStack {
                Circle().fill(conversation.isGroup ? accent.opacity(0.14) : accent)
                Text(conversation.isGroup ? "3" : initialsOf(conversation.title))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(conversation.isGroup ? accent : .white)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.title)
                    .font(.subheadline.weight(unread ? .bold : .semibold))
                    .foregroundStyle(Color.dealioTextPrimary)
                    .lineLimit(1)
                // Whose voice it was matters as much as the words — an inbox that
                // says only "ok, tomorrow works" tells you nothing about who to answer.
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.dealioTextSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(shortAgo(conversation.lastMessage?.createdAt))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.dealioTextSecondary)
                if unread {
                    Text("\(conversation.unreadCount)")
                        .font(.system(size: 9.5, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(unread ? accent : Color.dealioCardBorder, lineWidth: unread ? 1.5 : 1)
        )
    }

    private var subtitle: String {
        guard let last = conversation.lastMessage else { return kindLabel(conversation.kind, viewer: viewer) }
        let first = last.senderName.split(separator: " ").first.map(String.init) ?? ""
        return "\(first.isEmpty ? "Someone" : first): \(last.message)"
    }
}

/// The "+" sheet: everyone on this user's leads, and the rooms they can hold.
///
/// Rooms already open are listed too rather than hidden — the point of the picker
/// is "who can I talk to", and hiding the answers you already have makes that
/// list read as if those people were unavailable.
private struct CandidatePicker: View {
    let candidates: [Conversation]
    let loading: Bool
    let viewer: DealRole
    let onPick: (Conversation) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if candidates.isEmpty {
                    ContentUnavailableView("Nobody yet", systemImage: "person.2",
                        description: Text("Once you have a lead, the people on it appear here."))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(candidates, id: \.rowID) { candidate in
                                Button { onPick(candidate) } label: { row(candidate) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.dealioMist.ignoresSafeArea())
            .navigationTitle("Start a conversation")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func row(_ candidate: Conversation) -> some View {
        let accent = accentOf(candidate, viewer: viewer)
        return HStack(spacing: 10) {
            ZStack {
                Circle().fill(candidate.isGroup ? accent.opacity(0.14) : accent)
                Text(candidate.isGroup ? "3" : initialsOf(candidate.title))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(candidate.isGroup ? accent : .white)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(candidate.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.dealioTextPrimary)
                    .lineLimit(1)
                Text(kindLabel(candidate.kind, viewer: viewer))
                    .font(.caption2)
                    .foregroundStyle(Color.dealioTextSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if candidate.id != nil {
                Text("Open").font(.system(size: 10.5, weight: .bold)).foregroundStyle(accent)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.dealioCardBorder, lineWidth: 1)
        )
    }
}
