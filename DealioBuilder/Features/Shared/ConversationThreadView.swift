import SwiftUI

/// One conversation, read and written.
///
/// The only role-dependent thing here is which bubbles are yours, which follows
/// from `viewer` — the sender's role is on every message.

@MainActor
final class ConversationThreadModel: ObservableObject {
    @Published var loading = true
    @Published var sending = false
    @Published var error: String?
    @Published var toast: String?
    @Published var conversation: Conversation?
    @Published var messages: [ConversationMessage] = []

    func load(conversationId: Int) async {
        loading = messages.isEmpty
        error = nil
        do {
            let transcript = try await ThreadService.messages(conversationId: conversationId)
            conversation = transcript.conversation
            messages = transcript.messages
            // Best-effort: a failure costs a stale badge, never a lost message.
            await ThreadService.markRead(conversationId: conversationId)
        } catch {
            self.error = authMessage(error)
        }
        loading = false
    }

    func send(conversationId: Int, text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        sending = true
        defer { sending = false }
        do {
            // Append rather than reload: the transcript is already correct and a
            // full refetch would jump the list out from under a reader.
            let sent = try await ThreadService.send(conversationId: conversationId, message: trimmed)
            messages.append(sent)
        } catch {
            toast = authMessage(error)
        }
    }
}

struct ConversationThreadView: View {
    let conversationId: Int
    let viewer: DealRole

    @StateObject private var model = ConversationThreadModel()
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            // Who else is in the room. On a group this is the whole point; on a
            // pair it is a quiet confirmation you are writing to the right person.
            if let participants = model.conversation?.participants, !participants.isEmpty {
                Text(participants.joined(separator: " · "))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.dealioTextSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(Color(.secondarySystemGroupedBackground))
            }

            Group {
                if model.loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = model.error, model.messages.isEmpty {
                    VStack(spacing: 14) {
                        ErrorBanner(message: error)
                        Button("Try again") { Task { await model.load(conversationId: conversationId) } }
                            .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .padding()
                } else if model.messages.isEmpty {
                    VStack {
                        Text(emptyCopy)
                            .font(.footnote)
                            .foregroundStyle(Color.dealioTextSecondary)
                            .padding(24)
                        Spacer()
                    }
                } else {
                    // A chat that opens at the top of a long history is a chat you
                    // have to scroll before you can read it — and again after
                    // every send.
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(model.messages) { message in
                                    MessageBubble(message: message, viewer: viewer).id(message.id)
                                }
                            }
                            .padding(16)
                        }
                        .onChange(of: model.messages.count) { _, _ in
                            if let last = model.messages.last {
                                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                        .onAppear {
                            if let last = model.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            composer
        }
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle(model.conversation?.title ?? "Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(conversationId: conversationId) }
        .alert("Couldn't send", isPresented: Binding(
            get: { model.toast != nil },
            set: { if !$0 { model.toast = nil } }
        )) {
            Button("OK", role: .cancel) { model.toast = nil }
        } message: {
            Text(model.toast ?? "")
        }
    }

    private var emptyCopy: String {
        if model.conversation?.isGroup == true { return "No messages in this room yet." }
        return "No messages with \(model.conversation?.title ?? "this party") yet."
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.dealioFieldFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.dealioCardBorder, lineWidth: 1)
                )

            Button {
                let text = draft
                draft = ""
                Task { await model.send(conversationId: conversationId, text: text) }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.brandTeal)
                    if model.sending {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 48, height: 48)
                .opacity(canSend ? 1 : 0.4)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.sending
    }

    private var placeholder: String {
        if model.conversation?.isGroup == true { return "Message all three…" }
        return "Message \(model.conversation?.title ?? "…")…"
    }
}

private struct MessageBubble: View {
    let message: ConversationMessage
    let viewer: DealRole

    var body: some View {
        let mine = message.senderRole.lowercased() == viewer.wireName
        HStack {
            if mine { Spacer(minLength: 44) }
            VStack(alignment: .leading, spacing: 2) {
                if !mine, !message.senderName.isEmpty {
                    Text(message.senderName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(mine ? Color.white.opacity(0.8) : Color.dealioTextSecondary)
                }
                Text(message.message)
                    .font(.footnote)
                    .foregroundStyle(mine ? .white : Color.dealioTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if !message.createdAt.isEmpty {
                    Text(shortAgo(message.createdAt))
                        .font(.system(size: 9))
                        .foregroundStyle(mine ? Color.white.opacity(0.7) : Color.dealioTextSecondary)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(mine ? Color.brandTeal : Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(mine ? Color.clear : Color.dealioCardBorder, lineWidth: 1)
            )
            if !mine { Spacer(minLength: 44) }
        }
    }
}
