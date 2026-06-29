import SwiftUI

private let statusScore: [String: Int] = [
    "Negotiation": 88, "Meeting Done": 72, "Meeting Confirmed": 62,
    "Meeting Requested": 52, "Profile Created": 36, "New Lead": 22, "Booked": 95,
]
private let nextAction: [String: String] = [
    "New Lead": "Call to introduce yourself and understand their requirements",
    "Profile Created": "Share the project brochure and key features via WhatsApp",
    "Meeting Requested": "Coordinate with the builder to confirm the site-visit date",
    "Meeting Confirmed": "Send a warm reminder 24 hours before the site visit",
    "Meeting Done": "Follow up with pricing, payment plan and configurations",
    "Negotiation": "Share special offers and flexible payment plans to close",
    "Booked": "Congratulate and assist with documentation and loan",
]

private struct ScoredLead: Identifiable {
    let lead: CpLead
    let score: Int
    let label: String
    var id: Int { lead.id }
    var color: Color { label == "Hot" ? .red : label == "Warm" ? .orange : .blue }
}

private func score(_ lead: CpLead) -> ScoredLead {
    let base = statusScore[lead.status ?? ""] ?? 20
    let days = daysSince(lead.createdAt)
    let decay = min(Double(days) * 0.5, 20)
    let s = max(5, Int((Double(base) - decay).rounded()))
    let label = s >= 70 ? "Hot" : s >= 45 ? "Warm" : "Cold"
    return ScoredLead(lead: lead, score: s, label: label)
}

struct CPAIInsightsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPGrowthDataModel()
    @State private var filter = "All"
    @State private var expanded: Int?
    @Environment(\.openURL) private var openURL

    private var scored: [ScoredLead] {
        model.leads.filter { $0.status != "Closed" }.map(score).sorted { $0.score > $1.score }
    }
    private var shown: [ScoredLead] { filter == "All" ? scored : scored.filter { $0.label == filter } }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if model.loading { ProgressView().padding(.top, 40) } else {
                    HStack(spacing: 10) {
                        stat("Active", scored.count, .primary)
                        stat("Hot", scored.filter { $0.label == "Hot" }.count, .red)
                        stat("Warm", scored.filter { $0.label == "Warm" }.count, .orange)
                        stat("Cold", scored.filter { $0.label == "Cold" }.count, .blue)
                    }
                    Picker("Filter", selection: $filter) {
                        ForEach(["All", "Hot", "Warm", "Cold"], id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.segmented)

                    if shown.isEmpty {
                        ContentUnavailableView("No active leads", systemImage: "brain.head.profile",
                            description: Text("Add leads from the Projects page to see AI scoring.")).padding(.top, 30)
                    } else {
                        ForEach(shown) { s in leadCard(s) }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("AI Lead Intelligence")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(cpUserId: auth.user?.id ?? 0) }
    }

    private func leadCard(_ s: ScoredLead) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { withAnimation(.snappy) { expanded = expanded == s.id ? nil : s.id } } label: {
                HStack(spacing: 12) {
                    Text(String((s.lead.customerName ?? "?").prefix(1)).uppercased())
                        .font(.headline).foregroundStyle(s.color).frame(width: 40, height: 40)
                        .background(s.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(s.lead.customerName ?? "Lead").font(.subheadline.weight(.semibold))
                            Text("\(s.score) · \(s.label)").font(.caption2.weight(.bold))
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(s.color.opacity(0.15), in: Capsule()).foregroundStyle(s.color)
                        }
                        Text("\(s.lead.projectName ?? "—") · \(s.lead.status ?? "")").font(.caption).foregroundStyle(.secondary)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(.tertiarySystemFill)).frame(height: 5)
                                Capsule().fill(s.color).frame(width: geo.size.width * Double(s.score) / 100, height: 5)
                            }
                        }.frame(height: 5)
                    }
                    Image(systemName: "chevron.down").font(.caption).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if expanded == s.id {
                if let action = nextAction[s.lead.status ?? ""] {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "bolt.fill").foregroundStyle(.brandTeal).font(.caption)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("NEXT BEST ACTION").font(.caption2.weight(.bold)).foregroundStyle(.brandTeal)
                            Text(action).font(.caption)
                        }
                    }
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.brandTeal.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                if let phone = s.lead.customerPhone, !phone.isEmpty {
                    HStack(spacing: 10) {
                        Button { if let u = Share.telURL(phone) { openURL(u) } } label: {
                            Label("Call", systemImage: "phone.fill").font(.caption.weight(.semibold))
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(.green, in: Capsule()).foregroundStyle(.white)
                        }
                        Button {
                            if let u = Share.whatsAppURL(phone: phone, text: "Hi \(s.lead.customerName ?? ""), \(nextAction[s.lead.status ?? ""] ?? "checking in on your property search!")") { openURL(u) }
                        } label: {
                            Label("WhatsApp", systemImage: "message.fill").font(.caption.weight(.semibold))
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Color(red: 0.14, green: 0.83, blue: 0.4), in: Capsule()).foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .padding(14).cardSurface()
    }

    private func stat(_ label: String, _ value: Int, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text("\(value)").font(.title3.weight(.bold)).foregroundStyle(tint)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(10).cardSurface()
    }
}
