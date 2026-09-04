import SwiftUI
import UIKit

/// The window's own safe-area insets.
///
/// A hero that fills the status bar has to know how tall the status bar is, and
/// the usual `GeometryReader` trick cannot tell it: the shells wrap every page
/// in `.ignoresSafeArea(.container, edges: .top)`, so a reader *inside* a page
/// reports zero and the header collapses under the clock. Asking the window
/// instead gives the same answer everywhere, whatever any ancestor has ignored.
enum SafeArea {
    private static func insets() -> UIEdgeInsets? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows.first(where: \.isKeyWindow)?.safeAreaInsets
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first?.safeAreaInsets
    }

    /// Status-bar / notch inset. Falls back to a modern-iPhone value rather than
    /// zero — a header that guesses slightly tall reads as padding; one that
    /// guesses zero puts the title under the clock.
    static var top: CGFloat {
        let value = insets()?.top ?? 0
        return value > 0 ? value : 47
    }

    /// Home-indicator inset.
    static var bottom: CGFloat { insets()?.bottom ?? 0 }
}

// MARK: - Brand header

/// The navy→teal header every portal home screen wears, drawn so its background
/// runs all the way up behind the status bar.
///
/// Put it as the first child of a `ScrollView` that carries
/// `.ignoresSafeArea(.container, edges: .top)`; the header pads itself past the
/// clock so the content below the gradient still starts in the safe area.
struct BrandHeader<Content: View>: View {
    var cornerRadius: CGFloat = 28
    var topPadding: CGFloat = 12
    var bottomPadding: CGFloat = 20
    var horizontalPadding: CGFloat = 20
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.top, SafeArea.top + topPadding)
            .padding(.bottom, bottomPadding)
            .background(BrandHeaderBackground())
            .clipShape(
                UnevenRoundedRectangle(bottomLeadingRadius: cornerRadius,
                                       bottomTrailingRadius: cornerRadius,
                                       style: .continuous)
            )
    }
}

/// The gradient itself — navy into teal with two soft glow orbs, so the header
/// has depth rather than reading as a flat block of colour.
struct BrandHeaderBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.dealioNavyDeep, .dealioNavyMid, .dealioTealDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(RadialGradient(colors: [Color.dealioTealBright.opacity(0.34), .clear],
                                     center: .center, startRadius: 0, endRadius: 150))
                .frame(width: 300, height: 300)
                .offset(x: 130, y: -110)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            Circle()
                .fill(RadialGradient(colors: [Color.dealioOrange.opacity(0.16), .clear],
                                     center: .center, startRadius: 0, endRadius: 110))
                .frame(width: 220, height: 220)
                .offset(x: -60, y: 70)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .allowsHitTesting(false)
    }
}

extension View {
    /// Lets a page's own header paint the status bar. Pair with `BrandHeader`.
    func heroScrollEdges() -> some View {
        ignoresSafeArea(.container, edges: .top)
    }
}
