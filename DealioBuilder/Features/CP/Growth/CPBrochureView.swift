import SwiftUI

@MainActor
final class CPBrochureModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var profile: CpProfile?
    @Published var loading = true
    func load(cpUserId: Int) async {
        loading = projects.isEmpty
        async let projReq: [Project] = APIClient.shared.get("/customer/projects")
        async let profReq: CpProfile = APIClient.shared.get("/cp/\(cpUserId)/profile")
        projects = (try? await projReq) ?? []
        profile = try? await profReq
        loading = false
    }
}

struct CPBrochureView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPBrochureModel()
    @Environment(\.openURL) private var openURL
    @State private var selectedId: Int?

    private var selected: Project? { model.projects.first { $0.id == selectedId } ?? model.projects.first }
    private var cpName: String { model.profile?.fullName ?? auth.user?.fullName ?? "Your Agent" }
    private var cpPhone: String? { model.profile?.phone ?? auth.user?.phone }

    /// The brochure as forwardable text.
    ///
    /// Commission *is* on this one, unlike the flyer: a brochure goes to another
    /// partner or into the CP's own notes, not to the buyer.
    private func brochureText(_ p: Project) -> String {
        let configs = (p.configurations ?? []).filter { !$0.isEmpty }.joined(separator: " / ")
        let price = p.priceLow.map { Fmt.compactPrice($0) } ?? "Price on request"
        return [
            "🏠 *\(p.name)*",
            p.whereLine.nilIfEmpty.map { "📍 \($0)" },
            configs.nilIfEmpty.map { "🛏 \($0)" },
            "💰 Starting \(price)",
            p.commissionValue.map { "💼 Commission: \(Fmt.percent($0))" },
            "",
            "📞 Contact: *\(cpName)*" + (cpPhone.map { " — \($0)" } ?? ""),
            model.profile?.cp?.reraNumber?.nilIfEmpty.map { "✅ RERA: \($0)" },
        ].compactMap { $0 }.joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if model.loading {
                    ProgressView().padding(.top, 30)
                } else if model.projects.isEmpty {
                    ContentUnavailableView("No projects", systemImage: "building.2", description: Text("Brochures are generated from published projects."))
                } else {
                    Picker("Project", selection: Binding(get: { selected?.id ?? -1 }, set: { selectedId = $0 })) {
                        ForEach(model.projects) { Text($0.name).tag($0.id) }
                    }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 6).cardSurface().padding(.horizontal)

                    if let p = selected {
                        VStack(alignment: .leading, spacing: 0) {
                            ProjectHeroImage(project: p).frame(height: 180).clipped()
                            VStack(alignment: .leading, spacing: 8) {
                                Text(p.name).font(.title3.weight(.bold))
                                if let loc = p.whereLine.nilIfEmpty {
                                    Label(loc, systemImage: "mappin.and.ellipse")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                if let configs = (p.configurations ?? []).filter({ !$0.isEmpty }).nilIfEmptyChips {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(configs, id: \.self) { config in
                                                Text(config)
                                                    .font(.caption2.weight(.medium))
                                                    .foregroundStyle(Color.dealioTextSecondary)
                                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                                    .background(Color.dealioFieldFill, in: Capsule())
                                            }
                                        }
                                    }
                                }
                                if let price = p.priceLow {
                                    Text("Starting \(Fmt.compactPrice(price))").font(.subheadline.weight(.bold))
                                }
                                if let commission = p.commissionValue {
                                    Text("\(Fmt.percent(commission)) Commission")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Color.brandTeal)
                                        .padding(.horizontal, 10).padding(.vertical, 4)
                                        .background(Color(hex: 0xEAFAFC), in: Capsule())
                                }
                                Divider()
                                HStack(spacing: 10) {
                                    InitialsAvatar(name: cpName, tint: .dealioOrange, size: 36)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(cpName).font(.subheadline.weight(.semibold))
                                        if let phone = cpPhone { Text(phone).font(.caption).foregroundStyle(.secondary) }
                                        if let rera = model.profile?.cp?.reraNumber { Text("RERA: \(rera)").font(.caption2).foregroundStyle(.secondary) }
                                    }
                                }
                            }
                            .padding(14)
                        }
                        .cardSurface().padding(.horizontal)

                        HStack(spacing: 10) {
                            ShareLink(item: brochureText(p)) {
                                Label("Share", systemImage: "square.and.arrow.up").font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                                    .background(LinearGradient.brand, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
                            }
                            Button { if let u = Share.whatsAppURL(phone: cpPhone, text: brochureText(p)) { openURL(u) } } label: {
                                Text("WhatsApp").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 13)
                                    .background(Color(red: 0.14, green: 0.83, blue: 0.4), in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Brochure Generator")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(cpUserId: auth.user?.id ?? 0) }
    }
}

private extension Array where Element == String {
    /// Nil for an empty list, so a `if let` reads as "there is something to draw".
    var nilIfEmptyChips: [String]? { isEmpty ? nil : self }
}
