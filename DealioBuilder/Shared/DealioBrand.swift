import SwiftUI

// MARK: - Brand palette (mirrors the Android app's ui/theme/Color.kt)

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    static let dealioNavyDeep = Color(hex: 0x0B1B2E)
    static let dealioNavy = Color(hex: 0x0D1F35)
    static let dealioNavyMid = Color(hex: 0x112E50)
    static let dealioNavyPrimary = Color(hex: 0x1C3B59)

    static let dealioTeal = Color(hex: 0x0A9CB5)
    static let dealioTealBright = Color(hex: 0x1CD8EE)
    static let dealioTealDeep = Color(hex: 0x0A818A)

    static let dealioOrange = Color(hex: 0xFF8930)
    static let dealioMist = Color(hex: 0xF6F8FB)
    static let dealioFieldFill = Color(hex: 0xF3F6FA)
    static let dealioButtonDisabled = Color(hex: 0xE7ECF3)
    static let dealioCardBorder = Color(hex: 0xE3E9F1)
    static let dealioTextPrimary = Color(hex: 0x13243A)
    static let dealioTextSecondary = Color(hex: 0x5C6B80)
    static let dealioError = Color(hex: 0xC93B3B)
}

// MARK: - Dealio "D" mark

/// The architectural "D" glyph, ported path-for-path from the Android app's
/// `ic_dealio_mark.xml` (20×20 viewbox): a thick left bar with orange window
/// slots, a wide arc, and a teal rooftop dot.
private struct DealioDShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 20.0
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }

        var path = Path()
        // Outer D silhouette.
        path.move(to: p(3, 2))
        path.addLine(to: p(9, 2))
        path.addCurve(to: p(18, 10), control1: p(16, 2), control2: p(18, 6))
        path.addCurve(to: p(9, 18), control1: p(18, 14), control2: p(16, 18))
        path.addLine(to: p(3, 18))
        path.closeSubpath()
        // Inner cutout (even-odd → hole).
        path.move(to: p(6, 5.5))
        path.addLine(to: p(9, 5.5))
        path.addCurve(to: p(15, 10), control1: p(13.5, 5.5), control2: p(15, 7.5))
        path.addCurve(to: p(9, 14.5), control1: p(15, 12.5), control2: p(13.5, 14.5))
        path.addLine(to: p(6, 14.5))
        path.closeSubpath()
        return path
    }
}

/// The bare glyph (D + window slots + spire dot) drawn in a 20×20 space,
/// scaled to fill the given frame. Used inside `DealioMark`.
struct DealioMarkGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / 20.0
            ZStack(alignment: .topLeading) {
                DealioDShape()
                    .fill(Color.white.opacity(0.94), style: FillStyle(eoFill: true))

                // Orange window slots on the left bar.
                RoundedRectangle(cornerRadius: 0.5 * s, style: .continuous)
                    .fill(Color.dealioOrange.opacity(0.88))
                    .frame(width: 3 * s, height: 1.4 * s)
                    .offset(x: 3 * s, y: 7.8 * s)
                RoundedRectangle(cornerRadius: 0.5 * s, style: .continuous)
                    .fill(Color.dealioOrange.opacity(0.60))
                    .frame(width: 3 * s, height: 1.4 * s)
                    .offset(x: 3 * s, y: 11.4 * s)

                // Teal spire dot at the top of the arc.
                Circle()
                    .fill(Color.dealioTealBright.opacity(0.92))
                    .frame(width: 2.8 * s, height: 2.8 * s)
                    .offset(x: 14.8 * s, y: 4.4 * s)
            }
        }
    }
}

/// The squared D-mark on its navy gradient tile — same as the Android logo tile.
struct DealioMark: View {
    var size: CGFloat = 36
    private var cornerRadius: CGFloat { size / 4 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.dealioNavyDeep, Color(hex: 0x0E2542), .dealioNavyMid],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.dealioTealBright.opacity(0.25), lineWidth: 1.5)
                )
            DealioMarkGlyph()
                .frame(width: size * 0.55, height: size * 0.55)
        }
        .frame(width: size, height: size)
    }
}

/// Mark + "Dealio" wordmark, laid out horizontally.
struct DealioLogo: View {
    var markSize: CGFloat = 36
    var fontSize: CGFloat = 20
    var onDark: Bool = false

    var body: some View {
        HStack(spacing: markSize / 3) {
            DealioMark(size: markSize)
            (
                Text("Deal").foregroundColor(onDark ? .white : .dealioNavy)
                + Text("io").foregroundColor(onDark ? .dealioTealBright : .dealioTeal)
            )
            .font(.system(size: fontSize, weight: .bold))
            .tracking(-0.5)
        }
    }
}
