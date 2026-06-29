import SwiftUI

struct CPReferralView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPGrowthDataModel()
    @Environment(\.openURL) private var openURL

    private var code: String {
        let first = (model.profile?.fullName ?? auth.user?.fullName ?? "Partner")
            .split(separator: " ").first.map { String($0).uppercased() } ?? "PARTNER"
        let id = model.profile?.id ?? auth.user?.id ?? 0
        return "CP-\(first.prefix(6))-\(id)"
    }
    private var link: String { "https://dealio.app/login?ref=\(code)" }
    private var waMessage: String {
        "Join Dealio as a Channel Partner using my referral code: \(code)\n\nEarn commissions on real-estate deals across India.\n\nSign up: \(link)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Code card
                VStack(spacing: 14) {
                    Text("YOUR REFERRAL CODE").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Text(code).font(.title2.weight(.heavy)).tracking(1)
                        Button { Share.copy(code) } label: { Image(systemName: "doc.on.doc") }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    HStack(spacing: 10) {
                        Button {
                            if let u = Share.whatsAppURL(phone: nil, text: waMessage) { openURL(u) }
                        } label: {
                            Label("WhatsApp", systemImage: "message.fill").font(.caption.weight(.semibold))
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                .background(Color(red: 0.14, green: 0.83, blue: 0.4), in: Capsule()).foregroundStyle(.white)
                        }
                        ShareLink(item: link) {
                            Label("Share link", systemImage: "square.and.arrow.up").font(.caption.weight(.semibold))
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                .background(Color(.tertiarySystemFill), in: Capsule())
                        }
                    }
                }
                .padding(20).frame(maxWidth: .infinity).cardSurface().padding(.horizontal)

                // How it works
                VStack(alignment: .leading, spacing: 14) {
                    Text("How referrals work").font(.headline)
                    step(1, "Share your code", "Share with fellow real-estate agents.")
                    step(2, "They sign up", "They register with your code as a Level 1 referral.")
                    step(3, "Earn bonuses", "₹500 per Level-1 deal, ₹200 per Level-2 deal.")
                    step(4, "Track earnings", "Referral earnings show in your commissions.")
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface().padding(.horizontal)

                // Earnings
                HStack(spacing: 12) {
                    earn("₹500", "Per Level-1 deal", .brandTeal)
                    earn("₹200", "Per Level-2 deal", .indigo)
                }.padding(.horizontal)
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Referrals")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(cpUserId: auth.user?.id ?? 0) }
    }

    private func step(_ n: Int, _ title: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)").font(.caption.weight(.bold)).foregroundStyle(.brandTealDeep)
                .frame(width: 26, height: 26).background(Color.brandTeal.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
    private func earn(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "gift.fill").foregroundStyle(tint)
            Text(value).font(.title3.weight(.bold)).foregroundStyle(tint)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(14).cardSurface()
    }
}
