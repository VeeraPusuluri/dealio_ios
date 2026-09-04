import SwiftUI

/// Where a project's RERA registration stands.
///
/// A registration that has lapsed is worse than one that was never filed —
/// marketing an expired project is the thing the authority actually penalises —
/// so expiry is graded rather than reduced to registered/not.
enum ReraCompliance: String {
    case missing = "Missing"
    case noExpiry = "No expiry"
    case expired = "Expired"
    case expiringSoon = "Expiring soon"
    case valid = "Valid"

    var tint: Color {
        switch self {
        case .valid: return .dealioStatusGreen
        case .expiringSoon: return .dealioStatusAmber
        case .expired, .missing: return .dealioError
        case .noExpiry: return .dealioTextSecondary
        }
    }

    var icon: String {
        switch self {
        case .valid: return "checkmark.seal.fill"
        case .expiringSoon: return "clock.badge.exclamationmark.fill"
        case .expired, .missing: return "exclamationmark.triangle.fill"
        case .noExpiry: return "questionmark.circle.fill"
        }
    }

    /// Ninety days is the window in which a renewal has to be started, so it is
    /// the point at which "valid" stops being the useful answer.
    static func of(reraNumber: String?, expiry: String?) -> ReraCompliance {
        guard reraNumber?.nilIfEmpty != nil else { return .missing }
        guard let expiry = expiry?.nilIfEmpty,
              let date = MeetingCal.day(from: expiry) else { return .noExpiry }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days < 0 { return .expired }
        if days <= 90 { return .expiringSoon }
        return .valid
    }
}

struct BuilderRERAView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderProjectsModel()

    private func compliance(_ project: Project) -> ReraCompliance {
        ReraCompliance.of(reraNumber: project.reraNumber, expiry: project.reraExpiry)
    }
    private var registered: Int {
        model.projects.filter { compliance($0) != .missing }.count
    }
    private var needsAttention: Int {
        model.projects.filter { [.expired, .expiringSoon, .missing].contains(compliance($0)) }.count
    }

    var body: some View {
        Group {
            if model.loading { ProgressView() }
            else if model.projects.isEmpty {
                ContentUnavailableView("No projects", systemImage: "checkmark.seal",
                    description: Text("Add a project to track its RERA compliance."))
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            StatCard(title: "RERA-registered", value: "\(registered) of \(model.projects.count)",
                                     systemImage: "checkmark.seal", tint: .green)
                            StatCard(title: "Need attention", value: "\(needsAttention)",
                                     systemImage: "exclamationmark.triangle",
                                     tint: needsAttention > 0 ? .orange : .green)
                        }
                        VStack(spacing: 12) {
                            ForEach(model.projects) { project in
                                let status = compliance(project)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 12) {
                                        Image(systemName: status.icon)
                                            .font(.title3)
                                            .foregroundStyle(status.tint)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(project.name).font(.subheadline.weight(.semibold))
                                            Text(project.reraNumber?.nilIfEmpty ?? "No RERA number")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        StatusBadge(text: status.rawValue, color: status.tint)
                                    }
                                    InfoLine("Expiry", project.reraExpiry?.nilIfEmpty.map { Fmt.date($0) })
                                    InfoLine("State", project.reraState)
                                    InfoLine("Building permit", project.buildingPermitNumber)
                                }
                                .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("RERA Compliance")
        .navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
    }
}
