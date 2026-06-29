import SwiftUI
import UIKit

@MainActor
final class BuilderAIModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedId: Int?
    @Published var loading = true

    func load(builderId: Int) async {
        loading = projects.isEmpty
        projects = (try? await APIClient.shared.get("/builder/\(builderId)/projects")) ?? []
        if selectedId == nil { selectedId = projects.first?.id }
        loading = false
    }

    var selected: Project? { projects.first { $0.id == selectedId } }
}

private func englishDesc(_ p: Project) -> String {
    let loc = [p.locality, p.city].compactMap { $0 }.joined(separator: ", ")
    let price = (p.priceMin ?? 0) > 0 ? "starting \(Money.inr(p.priceMin))" : "at attractive prices"
    return "Discover exceptional living at \(p.name)\(loc.isEmpty ? "" : ", located in \(loc)"). Spacious homes \(price), world-class amenities and thoughtful design. \(p.status?.capitalized ?? "Now selling") — book your site visit today."
}
private func hindiDesc(_ p: Project) -> String {
    let loc = [p.locality, p.city].compactMap { $0 }.joined(separator: ", ")
    let price = (p.priceMin ?? 0) > 0 ? "\(Money.inr(p.priceMin)) से शुरू" : "आकर्षक कीमतों पर"
    return "\(loc.isEmpty ? "" : "\(loc) में स्थित ")\(p.name) में असाधारण जीवन का अनुभव करें। आधुनिक घर \(price), विश्वस्तरीय सुविधाएं और बेहतरीन डिज़ाइन। आज ही अपनी साइट विज़िट बुक करें।"
}

struct BuilderAIView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderAIModel()
    @State private var generated = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Generate SEO listing descriptions from a project's details.", systemImage: "sparkles")
                    .font(.subheadline).foregroundStyle(.secondary)

                if model.loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
                } else if model.projects.isEmpty {
                    ContentUnavailableView("No projects", systemImage: "building.2",
                        description: Text("Create a project to use the AI tools."))
                } else {
                    Picker("Project", selection: Binding(get: { model.selectedId ?? -1 }, set: { model.selectedId = $0; generated = false })) {
                        ForEach(model.projects) { Text($0.name).tag($0.id) }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface()

                    Button { withAnimation(.snappy) { generated = true } } label: {
                        Label("Generate descriptions", systemImage: "sparkles")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(LinearGradient.brand, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)
                    }

                    if generated, let p = model.selected {
                        DescCard(lang: "English", text: englishDesc(p))
                        DescCard(lang: "Hindi", text: hindiDesc(p))
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("AI Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
    }
}

private struct DescCard: View {
    let lang: String
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(lang.uppercased()).font(.caption.weight(.bold)).foregroundStyle(.brandTeal)
                Spacer()
                Button {
                    UIPasteboard.general.string = text
                } label: { Label("Copy", systemImage: "doc.on.doc").font(.caption.weight(.semibold)) }
            }
            Text(text).font(.subheadline).foregroundStyle(.primary)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }
}
