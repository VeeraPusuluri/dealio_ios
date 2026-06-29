import SwiftUI

@MainActor
final class PublicProjectsModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var loading = true
    func load() async {
        loading = projects.isEmpty
        projects = (try? await APIClient.shared.get("/customer/projects")) ?? []
        loading = false
    }
}

private enum SocialPlatform: String, CaseIterable, Identifiable {
    case whatsapp = "WhatsApp", instagram = "Instagram", facebook = "Facebook", linkedin = "LinkedIn"
    var id: String { rawValue }
}

private func caption(_ p: Project, _ platform: SocialPlatform) -> String {
    let loc = [p.locality, p.city].compactMap { $0 }.joined(separator: ", ")
    let price = (p.priceMin ?? 0) > 0 ? "Starting \(Money.inr(p.priceMin))" : "Price on request"
    let cityTag = (p.city ?? "").replacingOccurrences(of: " ", with: "")
    switch platform {
    case .instagram:
        return "✨ Your dream home awaits! 🏡\n\n\(p.name)\n📍 \(loc)\n💰 \(price)\n\nDM me for details, tours and exclusive offers! 🔑\n\n#\(cityTag)RealEstate #NewLaunch #DreamHome"
    case .linkedin:
        return "Exciting real-estate opportunity: \(p.name) in \(p.city ?? "").\n\n• \(price)\n• Status: \(p.status?.capitalized ?? "Available")\n\nIdeal for end-users and investors. Reach out for a detailed presentation.\n\n#RealEstate #Investment #\(cityTag)"
    case .facebook:
        return "🏠 Introducing \(p.name)!\n\n📍 \(p.city ?? "") | 💰 \(price)\n\nLimited units available. Comment \"INTERESTED\" or DM for details!\n\n#\(cityTag)Homes #RealEstate"
    case .whatsapp:
        return "🏠 *\(p.name)*\n📍 \(loc)\n💰 \(price)\n\nInterested? Reply to this message or call me for details!\n\n#RealEstate #\(cityTag)"
    }
}

struct CPContentStudioView: View {
    @StateObject private var model = PublicProjectsModel()
    @Environment(\.openURL) private var openURL
    @State private var selectedId: Int?
    @State private var platform: SocialPlatform = .whatsapp
    @State private var text = ""

    private var selected: Project? { model.projects.first { $0.id == selectedId } ?? model.projects.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if model.loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
                } else if model.projects.isEmpty {
                    ContentUnavailableView("No projects", systemImage: "building.2",
                        description: Text("Published projects appear here."))
                } else {
                    Text("1. Pick a project").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    Picker("Project", selection: Binding(get: { selected?.id ?? -1 }, set: { selectedId = $0; text = "" })) {
                        ForEach(model.projects) { Text($0.name).tag($0.id) }
                    }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 6).cardSurface()

                    Text("2. Choose platform").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    Picker("Platform", selection: $platform) {
                        ForEach(SocialPlatform.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).onChange(of: platform) { _, _ in text = "" }

                    Button {
                        if let p = selected { withAnimation(.snappy) { text = caption(p, platform) } }
                    } label: {
                        Label("Generate caption", systemImage: "sparkles").font(.headline)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(LinearGradient.brand, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)
                    }

                    if !text.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("GENERATED CAPTION").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                                Spacer()
                                Button { Share.copy(text) } label: { Label("Copy", systemImage: "doc.on.doc").font(.caption.weight(.semibold)) }
                            }
                            TextEditor(text: $text).frame(minHeight: 150).font(.subheadline)
                                .padding(8).background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                            HStack {
                                if platform == .whatsapp {
                                    Button { if let u = Share.whatsAppURL(phone: nil, text: text) { openURL(u) } } label: {
                                        Label("Share on WhatsApp", systemImage: "message.fill").font(.subheadline.weight(.semibold))
                                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                                            .background(Color(red: 0.14, green: 0.83, blue: 0.4), in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
                                    }
                                } else {
                                    ShareLink(item: text) {
                                        Label("Share", systemImage: "square.and.arrow.up").font(.subheadline.weight(.semibold))
                                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                                            .background(LinearGradient.brand, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
                                    }
                                }
                            }
                        }
                        .padding(16).cardSurface()
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Content Studio")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }
}
