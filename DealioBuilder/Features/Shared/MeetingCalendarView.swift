import SwiftUI

/// List vs. calendar toggle used by the role meetings screens.
enum MeetingViewMode: String, CaseIterable { case list = "List", calendar = "Calendar" }

/// A meeting normalised for the calendar — each role maps its own model to this.
struct CalMeeting: Identifiable {
    let id: String
    /// Day the meeting falls on (start-of-day, local).
    let day: Date
    let time: String?
    /// Primary line (customer or project name).
    let title: String
    /// Secondary line (project / builder / meeting type).
    let subtitle: String?
    let status: String?
    let color: Color

    /// Build from an ISO-ish date string ("2026-07-02" or "2026-07-02T…").
    init?(id: String, dateString: String?, time: String?, title: String, subtitle: String?, status: String?, color: Color) {
        guard let day = MeetingCal.day(from: dateString) else { return nil }
        self.id = id; self.day = day; self.time = time
        self.title = title; self.subtitle = subtitle; self.status = status; self.color = color
    }
}

enum MeetingCal {
    private static let parser: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func day(from iso: String?) -> Date? {
        guard let iso, iso.count >= 10 else { return nil }
        return parser.date(from: String(iso.prefix(10)))
    }

    static func prettyTime(_ t: String?) -> String? {
        guard let t, !t.isEmpty else { return nil }
        // "14:30" / "14:30:00" → "2:30 PM"; pass through anything already formatted.
        let parts = t.split(separator: ":")
        guard parts.count >= 2, let h = Int(parts[0]) else { return t }
        let min = parts[1].prefix(2)
        let ampm = h >= 12 ? "PM" : "AM"
        let h12 = h % 12 == 0 ? 12 : h % 12
        return "\(h12):\(min) \(ampm)"
    }
}

/// Month calendar of meetings with a per-day dot and a selected-day agenda.
/// Role-agnostic — pass a list of `CalMeeting`s.
struct MeetingCalendarView: View {
    let meetings: [CalMeeting]

    private let cal = Calendar.current
    @State private var monthAnchor = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var selected = Calendar.current.startOfDay(for: Date())

    private var byDay: [Date: [CalMeeting]] {
        Dictionary(grouping: meetings, by: { $0.day })
    }

    private var monthDays: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: monthAnchor) else { return [] }
        let first = interval.start
        let leading = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        let count = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for d in 0..<count { cells.append(cal.date(byAdding: .day, value: d, to: first)) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private var weekdaySymbols: [String] {
        let s = cal.shortStandaloneWeekdaySymbols   // Sun..Sat
        let start = cal.firstWeekday - 1
        return Array(s[start...] + s[..<start]).map { String($0.prefix(2)) }
    }

    private var selectedMeetings: [CalMeeting] {
        (byDay[selected] ?? []).sorted { ($0.time ?? "") < ($1.time ?? "") }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                monthCard
                agendaCard
            }
            .padding(16)
        }
        .background(Color.dealioMist.ignoresSafeArea())
    }

    private var monthCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text(monthAnchor.formatted(.dateTime.month(.wide).year()))
                    .font(.headline).foregroundStyle(.primary)
                Spacer()
                Button("Today") {
                    withAnimation { monthAnchor = cal.dateInterval(of: .month, for: Date())?.start ?? Date(); selected = cal.startOfDay(for: Date()) }
                }
                .font(.caption.weight(.medium)).buttonStyle(.bordered).tint(.brandTeal)
                Button { step(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(.borderless)
                Button { step(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(.borderless)
            }

            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { w in
                    Text(w.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date { dayCell(date) } else { Color.clear.frame(height: 40) }
                }
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.dealioCardBorder))
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = cal.isDate(date, inSameDayAs: selected)
        let isToday = cal.isDateInToday(date)
        let dots = byDay[date] ?? []
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selected = date }
        } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 14, weight: isSelected || isToday ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : (isToday ? Color.brandTeal : .primary))
                HStack(spacing: 2) {
                    ForEach(dots.prefix(3).indices, id: \.self) { i in
                        Circle().fill(isSelected ? Color.white.opacity(0.9) : dots[i].color).frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                isSelected ? Color.brandTeal : (isToday ? Color.brandTeal.opacity(0.12) : Color.clear),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private var agendaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selected.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.subheadline.weight(.bold))
            if selectedMeetings.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar").font(.title2).foregroundStyle(.tertiary)
                        Text("Nothing scheduled").font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 24)
                    Spacer()
                }
            } else {
                ForEach(selectedMeetings) { m in
                    HStack(alignment: .top, spacing: 10) {
                        RoundedRectangle(cornerRadius: 2).fill(m.color).frame(width: 3).frame(maxHeight: .infinity)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(m.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                                Spacer()
                                if let t = MeetingCal.prettyTime(m.time) {
                                    Text(t).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                                }
                            }
                            if let sub = m.subtitle, !sub.isEmpty {
                                Text(sub).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            if let status = m.status {
                                Text(status).font(.caption2.weight(.semibold)).foregroundStyle(m.color)
                                    .padding(.horizontal, 8).padding(.vertical, 2)
                                    .background(m.color.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.dealioCardBorder))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func step(_ months: Int) {
        withAnimation {
            if let d = cal.date(byAdding: .month, value: months, to: monthAnchor) { monthAnchor = d }
        }
    }
}
