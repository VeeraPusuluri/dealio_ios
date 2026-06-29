import SwiftUI
import Charts

private struct MonthPoint: Identifiable {
    let label: String
    let count: Int
    var id: String { label }
}

struct CPSocialAnalyticsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPGrowthDataModel()

    private var total: Int { model.leads.count }
    private var booked: Int { model.leads.filter { $0.status == "Booked" }.count }
    private var active: Int { model.leads.filter { ($0.status ?? "") != "Booked" && ($0.status ?? "") != "Closed" }.count }
    private var conversion: String { total > 0 ? String(format: "%.0f%%", Double(booked) / Double(total) * 100) : "0%" }

    private var trend: [MonthPoint] {
        let cal = Calendar.current
        let fmt = DateFormatter(); fmt.dateFormat = "MMM"; fmt.locale = Locale(identifier: "en_US_POSIX")
        return (0..<6).reversed().compactMap { back -> MonthPoint? in
            guard let date = cal.date(byAdding: .month, value: -back, to: Date()) else { return nil }
            let key = monthKey(date)
            let count = model.leads.filter { ($0.createdAt ?? "").hasPrefix(key) }.count
            return MonthPoint(label: fmt.string(from: date), count: count)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if model.loading { ProgressView().padding(.top, 40) } else {
                    HStack(spacing: 12) {
                        metric("Total Leads", "\(total)", .primary)
                        metric("Active", "\(active)", .orange)
                    }
                    HStack(spacing: 12) {
                        metric("Closed", "\(booked)", .green)
                        metric("Conversion", conversion, .brandTeal)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monthly lead trend").font(.subheadline.weight(.bold))
                        Text("Last 6 months").font(.caption).foregroundStyle(.secondary)
                        Chart(trend) { point in
                            LineMark(x: .value("Month", point.label), y: .value("Leads", point.count))
                                .foregroundStyle(Color.brandTeal)
                                .interpolationMethod(.catmullRom)
                            PointMark(x: .value("Month", point.label), y: .value("Leads", point.count))
                                .foregroundStyle(Color.brandTeal)
                            AreaMark(x: .value("Month", point.label), y: .value("Leads", point.count))
                                .foregroundStyle(LinearGradient(colors: [.brandTeal.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                                .interpolationMethod(.catmullRom)
                        }
                        .frame(height: 180)
                        .chartYAxis { AxisMarks(position: .leading) }
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Leads per month").font(.subheadline.weight(.bold))
                        Chart(trend) { point in
                            BarMark(x: .value("Month", point.label), y: .value("Leads", point.count))
                                .foregroundStyle(Color.brandTeal)
                                .cornerRadius(4)
                        }
                        .frame(height: 160)
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Social Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(cpUserId: auth.user?.id ?? 0) }
    }

    private func metric(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.weight(.bold)).foregroundStyle(tint)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16).cardSurface()
    }
}
