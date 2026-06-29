import SwiftUI

@MainActor
final class CPProfileModel: ObservableObject {
    @Published var profile: CpProfile?
    @Published var loading = true

    func load(cpUserId: Int) async {
        loading = profile == nil
        profile = try? await APIClient.shared.get("/cp/\(cpUserId)/profile")
        loading = false
    }
}

struct CPProfileView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPProfileModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    let cp = model.profile?.cp
                    let name = model.profile?.fullName ?? auth.user?.fullName ?? "Partner"

                    // Header
                    VStack(spacing: 12) {
                        InitialsAvatar(name: name, size: 72)
                        VStack(spacing: 4) {
                            Text(name).font(.title3.weight(.bold))
                            if let tier = cp?.tier {
                                Text("\(tier) Partner").font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10).padding(.vertical, 3)
                                    .background(Color.dealioOrange.opacity(0.15), in: Capsule())
                                    .foregroundStyle(Color.dealioOrange)
                            }
                        }
                    }
                    .padding(.top, 16)

                    // Details
                    VStack(spacing: 0) {
                        InfoRow(label: "Phone", value: model.profile?.phone ?? auth.user?.phone ?? "—")
                        InfoRow(label: "Email", value: model.profile?.email ?? "—")
                        InfoRow(label: "City", value: cp?.city ?? "—")
                        InfoRow(label: "RERA", value: cp?.reraNumber ?? "—")
                    }
                    .padding(.horizontal, 16).cardSurface().padding(.horizontal)

                    // Verification
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "Verification").padding(.vertical, 10)
                        VerifyRow(label: "Phone", verified: cp?.phoneVerified ?? false)
                        VerifyRow(label: "Aadhaar", verified: cp?.aadhaarVerified ?? false)
                        VerifyRow(label: "PAN", verified: cp?.panVerified ?? false)
                        VerifyRow(label: "RERA", verified: cp?.reraVerified ?? false)
                    }
                    .padding(.horizontal, 16).cardSurface().padding(.horizontal)

                    Button(role: .destructive) { auth.logout() } label: {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .background(Color.dealioMist.ignoresSafeArea())
            .navigationTitle("Profile")
            .task { await model.load(cpUserId: auth.user?.id ?? 0) }
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).lineLimit(1)
        }
        .font(.subheadline).padding(.vertical, 13)
        .overlay(Divider(), alignment: .bottom)
    }
}

private struct VerifyRow: View {
    let label: String
    let verified: Bool
    var body: some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Label(verified ? "Verified" : "Pending", systemImage: verified ? "checkmark.seal.fill" : "clock")
                .font(.caption.weight(.semibold))
                .foregroundStyle(verified ? .green : .secondary)
        }
        .padding(.vertical, 12)
        .overlay(Divider(), alignment: .bottom)
    }
}
