import SwiftUI

// MARK: - Brand palette & gradients

extension ShapeStyle where Self == Color {
    /// Dealio brand teal (#0A7E8C).
    static var brandTeal: Color { Color(red: 0.039, green: 0.494, blue: 0.553) }
    /// Lighter teal used as a gradient highlight.
    static var brandTealLight: Color { Color(red: 0.106, green: 0.682, blue: 0.741) }
    /// Deeper teal used as a gradient base.
    static var brandTealDeep: Color { Color(red: 0.020, green: 0.349, blue: 0.396) }
}

extension ShapeStyle where Self == LinearGradient {
    /// Primary brand gradient (top-leading → bottom-trailing).
    static var brand: LinearGradient {
        LinearGradient(
            colors: [.brandTealLight, .brandTeal, .brandTealDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// A subtle vertical gradient for a single tint — used for icon tiles.
func tintGradient(_ color: Color) -> LinearGradient {
    LinearGradient(
        colors: [color.opacity(0.92), color],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Card surface

/// A soft, elevated card surface that adapts to light/dark mode — the look
/// used across Apple's Health / Wallet / App Store cards. Uses continuous
/// (squircle) corners and a faint shadow for depth in light mode.
private struct CardSurface: ViewModifier {
    var cornerRadius: CGFloat = 18
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(scheme == .dark ? 0.06 : 0), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.06), radius: 12, x: 0, y: 5)
    }
}

extension View {
    /// Wraps the view in the standard elevated Dealio card surface.
    func cardSurface(cornerRadius: CGFloat = 18) -> some View {
        modifier(CardSurface(cornerRadius: cornerRadius))
    }
}

// MARK: - Icon badge

/// A rounded, gradient-filled icon tile (the "Settings app icon" look).
struct IconBadge: View {
    let systemImage: String
    var tint: Color = .brandTeal
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                tintGradient(tint),
                in: RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
            )
            .shadow(color: tint.opacity(0.35), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title3.weight(.bold))
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Stat card

struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color
    /// Optional tap action — when set, the whole card becomes a button.
    var action: (() -> Void)? = nil

    var body: some View {
        if let action {
            Button(action: action) { card }.buttonStyle(.plain)
        } else {
            card
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                IconBadge(systemImage: systemImage, tint: tint)
                Spacer()
                if action != nil {
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardSurface()
    }
}

// MARK: - Status badge

struct StatusBadge: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        Text(text.capitalized)
            .font(.caption2.weight(.semibold))
            .textCase(nil)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }
}

/// Maps a Dealio stage/status string to a colour.
func statusColor(_ status: String?) -> Color {
    switch (status ?? "").lowercased() {
    case let s where s.contains("closed") || s.contains("booked") || s.contains("sold") || s.contains("won"):
        return .green
    case let s where s.contains("negotiation") || s.contains("agreement") || s.contains("pending"):
        return .orange
    case let s where s.contains("lost") || s.contains("cancel") || s.contains("reject"):
        return .red
    case let s where s.contains("meeting"):
        return .purple
    default:
        return .brandTeal
    }
}

// MARK: - Avatar

/// A circular gradient avatar showing initials — used in lead/customer rows.
struct InitialsAvatar: View {
    let name: String?
    var tint: Color = .brandTeal
    var size: CGFloat = 44

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tintGradient(tint), in: Circle())
    }

    private var initials: String {
        let parts = (name ?? "?").split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        let result = String(letters).uppercased()
        return result.isEmpty ? "?" : result
    }
}

// MARK: - Error banner

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.orange.opacity(0.25), lineWidth: 0.5)
        )
    }
}

// MARK: - Formatting

enum Money {
    /// Indian-format short currency: ₹1.20 Cr, ₹45 L, ₹12,500.
    static func inr(_ value: Double?) -> String {
        guard let value, value > 0 else { return "—" }
        if value >= 1_00_00_000 { return String(format: "₹%.2f Cr", value / 1_00_00_000) }
        if value >= 1_00_000 { return String(format: "₹%.2f L", value / 1_00_000) }
        let formatted = NumberFormatter.inr.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        return "₹\(formatted)"
    }
}

extension NumberFormatter {
    static let inr: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_IN")
        return formatter
    }()
}
