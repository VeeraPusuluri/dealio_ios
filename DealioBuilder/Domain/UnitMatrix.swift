import SwiftUI

/// A project's units, and the grid that shows them.
///
/// The website has always let a buyer pick an actual unit — Tower A, floor 7,
/// unit 703 — from the project's stored `unitMatrix`, and it is the unit id that
/// travels on the shortlist, the pricing request and eventually the booking.
///
/// Shared by all three portals deliberately: the buyer picks from this grid, and
/// the builder and the partner read the same grid, so all three are looking at
/// one inventory rather than three renderings of it. Mirrors Android's
/// `ui/flow/UnitMatrix.kt`.

// MARK: - The row

/// One unit on a project's matrix — `project.unitMatrix[]`.
struct UnitRow: Codable, Identifiable, Hashable {
    var id: String = ""
    var tower: String?
    var floor: Int?
    var unit: Int?
    var bhk: String?
    var areaSqft: Int?
    /// "Available" | "Booked" | "Sold" | "Hold", loosely — see `UnitStatus.of`.
    var status: String?
    var price: Double?
    var facing: String?

    private enum CodingKeys: String, CodingKey {
        case id, tower, floor, unit, bhk, areaSqft, status, price, facing
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        tower = try c.decodeIfPresent(String.self, forKey: .tower)
        floor = try c.decodeIfPresent(Int.self, forKey: .floor)
        unit = try c.decodeIfPresent(Int.self, forKey: .unit)
        bhk = try c.decodeIfPresent(String.self, forKey: .bhk)
        areaSqft = try c.decodeIfPresent(Int.self, forKey: .areaSqft)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        price = try c.decodeIfPresent(Double.self, forKey: .price)
        facing = try c.decodeIfPresent(String.self, forKey: .facing)
    }

    init(id: String, tower: String? = nil, floor: Int? = nil, unit: Int? = nil,
         bhk: String? = nil, areaSqft: Int? = nil, status: String? = nil,
         price: Double? = nil, facing: String? = nil) {
        self.id = id; self.tower = tower; self.floor = floor; self.unit = unit
        self.bhk = bhk; self.areaSqft = areaSqft; self.status = status
        self.price = price; self.facing = facing
    }
}

// MARK: - Status

enum UnitStatus: CaseIterable {
    case available, booked, sold, held

    var label: String {
        switch self {
        case .available: return "Available"
        case .booked: return "Booked"
        case .sold: return "Sold"
        case .held: return "On hold"
        }
    }

    var foreground: Color {
        switch self {
        case .available: return Color(hex: 0x0F766E)
        case .booked: return Color(hex: 0xB45309)
        case .sold: return Color(hex: 0x9F1239)
        case .held: return Color(hex: 0x4B5563)
        }
    }

    var background: Color {
        switch self {
        case .available: return Color(hex: 0xDCF5F1)
        case .booked: return Color(hex: 0xFDF3E7)
        case .sold: return Color(hex: 0xFDE7EC)
        case .held: return Color(hex: 0xEDEFF2)
        }
    }

    var isPickable: Bool { self == .available }

    /// Fold a stored status onto the four the grid draws.
    ///
    /// The column is free text written by the project wizard, the booking flow
    /// and the admin console, so it carries several spellings of the same three
    /// states. Anything unrecognised reads as available, which matches the
    /// website — a unit with a status nobody set is one nobody has taken.
    static func of(_ raw: String?) -> UnitStatus {
        switch raw?.trimmingCharacters(in: .whitespaces).lowercased() {
        case "booked", "blocked", "reserved": return .booked
        case "sold", "registered": return .sold
        case "hold", "on hold", "on-hold": return .held
        default: return .available
        }
    }
}

// MARK: - Deriving the matrix

enum Units {
    /// "Floor 7" / "Ground" — the ground floor is not floor 0 to a buyer.
    static func floorLabel(_ floor: Int?) -> String {
        guard let floor else { return "—" }
        return floor == 0 ? "Ground" : "Floor \(floor)"
    }

    /// "Unit A-703 · 2 BHK · 1240 sqft", with the missing parts left out.
    static func summary(_ unit: UnitRow) -> String {
        var parts = ["Unit \(unit.id)"]
        if let bhk = unit.bhk, !bhk.isEmpty { parts.append(bhk) }
        if let area = unit.areaSqft, area > 0 { parts.append("\(area) sqft") }
        return parts.joined(separator: " · ")
    }

    /// The units of a project, stored or derived.
    ///
    /// Most projects carry a real `unitMatrix`. Older ones — created before the
    /// wizard collected it — carry only a total, a tower count and a
    /// configuration list, and the website synthesizes a plausible grid from
    /// those rather than showing a buyer nothing. This mirrors that synthesis
    /// exactly, so the same project offers the same unit ids on the web and in
    /// the app; a shortlist made on one is a unit the other can find.
    static func of(_ project: Project) -> [UnitRow] {
        if let matrix = project.unitMatrix, !matrix.isEmpty { return matrix }

        let total = project.totalUnits ?? 0
        guard total > 0 else { return [] }
        let configs = (project.configurations ?? []).filter { !$0.isEmpty }
        let bhks = configs.isEmpty ? ["2 BHK"] : configs
        let floors = project.floorsPerTower ?? min(max((total + 3) / 4, 1), 15)
        let perFloor = max((total + floors - 1) / floors, 1)

        var out: [UnitRow] = []
        out.reserveCapacity(total)
        for floor in 1...max(floors, 1) {
            for unit in 1...perFloor {
                if out.count >= total { return out }
                out.append(UnitRow(
                    // The website's exact expression, `A-${floor}0${unit}`, not a
                    // zero-padded equivalent. They agree up to nine units a floor
                    // and part company at ten: the web mints "A-1010" where
                    // padding would give "A-110". Only one of those is the *same*
                    // name, and a shortlist made in the browser has to be the
                    // unit this grid highlights.
                    id: "A-\(floor)0\(unit)",
                    tower: "A", floor: floor, unit: unit,
                    bhk: bhks[(unit - 1) % bhks.count],
                    status: "Available"
                ))
            }
        }
        return out
    }

    /// Only what a buyer may actually take.
    static func available(_ project: Project) -> [UnitRow] {
        of(project).filter { UnitStatus.of($0.status).isPickable }
    }

    /// Tally a project's units from the matrix, falling back to the stored
    /// counters. The matrix is the truth when it exists — `availableUnits` /
    /// `bookedUnits` are maintained by hand and drift the moment anyone edits the
    /// matrix directly. Where there is no matrix the counters are all there is.
    static func tally(_ project: Project) -> UnitTally {
        guard let matrix = project.unitMatrix, !matrix.isEmpty else {
            let total = project.totalUnits ?? 0
            let booked = project.bookedUnits ?? 0
            let sold = project.soldUnits ?? 0
            return UnitTally(total: total,
                             available: project.availableUnits ?? max(total - booked - sold, 0),
                             booked: booked, sold: sold)
        }
        let grouped = Dictionary(grouping: matrix) { UnitStatus.of($0.status) }
        return UnitTally(total: matrix.count,
                         available: grouped[.available]?.count ?? 0,
                         booked: grouped[.booked]?.count ?? 0,
                         sold: grouped[.sold]?.count ?? 0)
    }
}

/// The counts a builder reads at a glance, derived rather than stored.
struct UnitTally { let total: Int; let available: Int; let booked: Int; let sold: Int }

// MARK: - The grid

/// The unit matrix, one row per floor, highest floor at the top.
///
/// Floors descend because that is how a stack plan is read and how every sales
/// office pins it to the wall — the penthouse is at the top of the board, not
/// scrolled to the bottom of it.
struct UnitMatrixGrid: View {
    let units: [UnitRow]
    /// When false the grid is a read-only inventory board, which is what the
    /// builder and the partner see.
    var selectable = false
    var selected: String?
    var onSelect: (UnitRow) -> Void = { _ in }

    var body: some View {
        if units.isEmpty {
            Text("No unit inventory has been published for this project yet.")
                .font(.footnote)
                .foregroundStyle(Color.dealioTextSecondary)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                legend
                // Towers first, then floors within each — a matrix with two
                // towers rendered as one flat list of floors would stack A-701
                // next to B-701 with nothing saying they are different buildings.
                ForEach(towers, id: \.name) { tower in
                    VStack(alignment: .leading, spacing: 6) {
                        if towers.count > 1 || tower.name != "—" {
                            Text("TOWER \(tower.name)".uppercased())
                                .font(.system(size: 9.5, weight: .black))
                                .tracking(0.7)
                                .foregroundStyle(Color.dealioTextSecondary)
                        }
                        ForEach(floors(of: tower.units), id: \.floor) { row in
                            HStack(spacing: 6) {
                                Text(row.floor == 0 ? "G" : "\(row.floor)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.dealioTextSecondary)
                                    .frame(width: 22, alignment: .trailing)
                                // Horizontal, not wrapped: a floor is a row of
                                // units and wrapping one onto two lines reads as
                                // two floors.
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 5) {
                                        ForEach(row.units) { unit in
                                            cell(unit)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private struct Tower { let name: String; let units: [UnitRow] }
    private struct FloorRow { let floor: Int; let units: [UnitRow] }

    private var towers: [Tower] {
        Dictionary(grouping: units) { unit -> String in
            let tower = unit.tower ?? ""
            return tower.isEmpty ? "—" : tower
        }
        .map { Tower(name: $0.key, units: $0.value) }
        .sorted { $0.name < $1.name }
    }

    private func floors(of towerUnits: [UnitRow]) -> [FloorRow] {
        Dictionary(grouping: towerUnits) { $0.floor ?? 0 }
            .map { FloorRow(floor: $0.key, units: $0.value.sorted { ($0.unit ?? 0) < ($1.unit ?? 0) }) }
            .sorted { $0.floor > $1.floor }
    }

    private func cell(_ unit: UnitRow) -> some View {
        let status = UnitStatus.of(unit.status)
        let isSelected = selectable && unit.id == selected
        // A taken unit is never tappable even in a selectable grid — the buyer
        // must be able to see the whole board, and see what is gone.
        let enabled = selectable && status.isPickable
        return Button { onSelect(unit) } label: {
            VStack(spacing: 1) {
                Text(unit.id)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isSelected ? .white : status.foreground)
                    .lineLimit(1)
                if let bhk = unit.bhk, !bhk.isEmpty {
                    Text(bhk)
                        .font(.system(size: 8))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.85) : status.foreground.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .frame(width: 58)
            .padding(.vertical, 6).padding(.horizontal, 4)
            .background(isSelected ? Color.brandTeal : status.background,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.brandTeal : Color.dealioCardBorder,
                                  lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(UnitStatus.allCases, id: \.self) { status in
                HStack(spacing: 4) {
                    Circle().fill(status.foreground).frame(width: 8, height: 8)
                    Text(status.label)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Color.dealioTextSecondary)
                }
            }
        }
    }
}

/// A one-line summary of a picked unit, for confirming a choice before sending it.
struct PickedUnitRow: View {
    let unit: UnitRow

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(Units.summary(unit))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.dealioTextPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.dealioTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(Color.brandTeal.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.brandTeal.opacity(0.4), lineWidth: 1)
        )
    }

    private var detail: String {
        var parts: [String] = []
        if let tower = unit.tower, !tower.isEmpty { parts.append("Tower \(tower)") }
        parts.append(Units.floorLabel(unit.floor))
        return parts.joined(separator: " · ")
    }
}
