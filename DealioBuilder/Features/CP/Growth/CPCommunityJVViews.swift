import SwiftUI

struct CPCommunityView: View {
    @Environment(\.openURL) private var openURL

    private let features: [(String, String, String)] = [
        ("bell.badge", "Society Notices", "Broadcast updates, events and maintenance alerts to residents."),
        ("gift", "Group Deals", "Negotiate bulk discounts with interior and appliance vendors."),
        ("bubble.left.and.bubble.right", "Resident Forum", "A private forum for residents to connect and share."),
        ("storefront", "Vendor Marketplace", "Vetted vendors for painting, carpentry and interiors at pre-negotiated rates."),
        ("square.and.arrow.up.on.square", "Resident Onboarding", "Upload a CSV of flat owners to enable group-buying power."),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    Image(systemName: "person.3.fill").font(.largeTitle).foregroundStyle(.white)
                        .frame(width: 64, height: 64).background(LinearGradient.brand, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    Text("Community Hub").font(.title3.weight(.bold))
                    Text("After a deal closes, stay connected with buyers — creating referrals and long-term loyalty.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Text("Launching Soon").font(.caption.weight(.bold)).padding(.horizontal, 12).padding(.vertical, 5)
                        .background(.orange.opacity(0.15), in: Capsule()).foregroundStyle(.orange)
                }
                .padding(24).frame(maxWidth: .infinity).cardSurface().padding(.horizontal)

                VStack(alignment: .leading, spacing: 16) {
                    Text("What's coming").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    ForEach(features, id: \.0) { f in
                        HStack(alignment: .top, spacing: 12) {
                            IconBadge(systemImage: f.0, tint: .brandTeal, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.1).font(.subheadline.weight(.semibold))
                                Text(f.2).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface().padding(.horizontal)

                Button {
                    if let u = Share.whatsAppURL(phone: "9000000000", text: "Hi Dealio team! I'd like early access to the Community Hub feature.") { openURL(u) }
                } label: {
                    Label("Request early access", systemImage: "message.fill").font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(LinearGradient.brand, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.white)
                }.padding(.horizontal)
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Community")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CPJVView: View {
    var body: some View {
        ContentUnavailableView("No JV listings yet", systemImage: "hands.sparkles",
            description: Text("Joint-venture opportunities between channel partners and landowners will appear here once available."))
            .background(Color(.systemGroupedBackground))
            .navigationTitle("JV Opportunities")
            .navigationBarTitleDisplayMode(.inline)
    }
}
