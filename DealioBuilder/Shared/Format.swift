import Foundation

/// Formatting the whole app agrees on.
///
/// The same values are rendered on three portals and in a shared flyer, so they
/// are computed once here rather than re-derived per screen. Mirrors Android's
/// `ui/builder/Format.kt`.

extension Project {
    /// Price range works across both endpoints — `priceMin`/`priceMax` on the
    /// detail, `priceFrom`/`priceTo` on the list.
    var priceLow: Double? { priceMin }
    var priceHigh: Double? { priceMax }

    /// Units still on offer.
    ///
    /// `availableUnits` is optional in the project form and null on many live
    /// projects, so reading it as `?? 0` reports a sold-out project whenever the
    /// builder only filled in the total. Fall back to the unaccounted-for
    /// remainder. Nil only when the total is unknown too, so callers can show
    /// "—" rather than inventing a zero.
    var availableUnitsOrDerived: Int? {
        if let available = availableUnits { return available }
        guard let total = totalUnits else { return nil }
        return min(max(total - (bookedUnits ?? 0) - (soldUnits ?? 0), 0), total)
    }

    /// "Kondapur, Hyderabad" — the parts that exist, in the order a person says them.
    var whereLine: String {
        [locality, city].compactMap { $0?.nilIfEmpty }.joined(separator: ", ")
    }
}

enum Fmt {
    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                 "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// `yyyy-MM-dd` or ISO → "12 Jun 2026". Falls back to the raw string.
    static func date(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "—" }
        let parts = raw.prefix(10).split(separator: "-")
        guard parts.count == 3, let month = Int(parts[1]), months.indices.contains(month - 1) else { return raw }
        let day = Int(parts[2]).map(String.init) ?? String(parts[2])
        return "\(day) \(months[month - 1]) \(parts[0])"
    }

    /// `yyyy-MM-dd` → "Oct 2027". Nil when there is no usable date.
    ///
    /// A browse card compares possession across projects, where the day of the
    /// month is noise: "1 Oct 2027" beside "15 Dec 2026" invites a comparison of
    /// two digits that mean nothing.
    static func monthYear(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let parts = raw.prefix(10).split(separator: "-")
        guard parts.count == 3, let month = Int(parts[1]), months.indices.contains(month - 1) else { return raw }
        return "\(months[month - 1]) \(parts[0])"
    }

    /// "UNDER_CONSTRUCTION" → "Under Construction".
    static func titleCase(_ raw: String?) -> String {
        (raw ?? "").lowercased()
            .split(whereSeparator: { $0 == "_" || $0 == " " })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    /// Compact INR — ₹1.2 Cr / ₹85 L. Shared by the caption and flyer builders.
    ///
    /// Trailing zeros come off so "₹1.50 Cr" reads "₹1.5 Cr" and "₹2.00 Cr"
    /// reads "₹2 Cr" — a price with decimals nobody typed looks like a quote
    /// rather than a headline.
    static func compactPrice(_ value: Double) -> String {
        if value >= 1_00_00_000 {
            var crore = String(format: "%.2f", value / 1_00_00_000)
            while crore.hasSuffix("0") { crore.removeLast() }
            if crore.hasSuffix(".") { crore.removeLast() }
            return "₹\(crore) Cr"
        }
        if value >= 1_00_000 { return "₹\(Int(value / 1_00_000)) L" }
        return "₹\(Int(value))"
    }

    /// Short INR for stat tiles — ₹1.2Cr / ₹45L, no space.
    static func shortRupee(_ value: Double) -> String {
        if value >= 1_00_00_000 { return "₹\(String(format: "%.1f", value / 1_00_00_000))Cr" }
        if value >= 1_00_000 { return "₹\(Int(value / 1_00_000))L" }
        return "₹\(Int(value))"
    }

    /// The name to greet someone by.
    ///
    /// The first word alone reads fine for "Rajesh Kumar", but collapses to a
    /// single letter for "V Prasad Reddy" and to "Sri" for "Sri Sai
    /// Constructions" — so keep taking words until there is enough of the name
    /// left to recognise.
    static func greetingName(_ name: String?, fallback: String = "there") -> String {
        let parts = (name ?? "").split(whereSeparator: \.isWhitespace).map(String.init)
        guard let first = parts.first else { return fallback }
        var out = first
        for word in parts.dropFirst().prefix(2) {
            if out.count >= 16 { break }
            out += " " + word
        }
        return out
    }

    /// "2.5%" / "3%" — a commission rate without the decimal nobody typed.
    static func percent(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(value))%" : "\(value)%"
    }

    static func initials(_ name: String?) -> String {
        let parts = (name ?? "").split(separator: " ").prefix(2).compactMap { $0.first }
        let letters = String(parts).uppercased()
        return letters.isEmpty ? "?" : letters
    }
}
