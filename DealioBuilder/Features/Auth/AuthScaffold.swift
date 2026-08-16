import SwiftUI

/// Bottom-only rounded rectangle for the brand hero.
private struct BottomRoundedShape: Shape {
    var radius: CGFloat = 32
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadii: RectangleCornerRadii(
            topLeading: 0, bottomLeading: radius, bottomTrailing: radius, topTrailing: 0
        ))
    }
}

/// Branded shell for the auth screens: a navy gradient hero (teal glow + trust
/// strip) carrying the Dealio mark and headline, flowing into a floating white
/// form card that overlaps the hero, with a footer pinned to the bottom.
struct AuthScaffold<Content: View, HeroTrailing: View>: View {
    let headline: String
    let subtitle: String
    /// Eyebrow above the headline — "Sign in", "Step 2 · Verify".
    var eyebrow: String? = nil
    /// The colour the hero glows in. Defaults to the brand teal, which is what
    /// anything outside the role picker wants.
    var accentOnDark: Color = .dealioTealBright
    /// Which of the two steps we're on, for the progress track. 0 hides it.
    var step: Int = 0
    /// Sits opposite the logo — the role chip on sign-in.
    @ViewBuilder var heroTrailing: () -> HeroTrailing
    @ViewBuilder var content: () -> Content

    init(
        headline: String,
        subtitle: String,
        eyebrow: String? = nil,
        accentOnDark: Color = .dealioTealBright,
        step: Int = 0,
        @ViewBuilder heroTrailing: @escaping () -> HeroTrailing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.headline = headline
        self.subtitle = subtitle
        self.eyebrow = eyebrow
        self.accentOnDark = accentOnDark
        self.step = step
        self.heroTrailing = heroTrailing
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            let topInset = geo.safeAreaInsets.top
            let bottomInset = geo.safeAreaInsets.bottom
            let fullHeight = geo.size.height + topInset + bottomInset

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    hero(topInset: topInset)

                    card
                        .padding(.horizontal, 16)
                        .offset(y: -30)

                    Spacer(minLength: 16)

                    Text("By continuing you agree to our Terms & Privacy Policy.")
                        .font(.caption)
                        .foregroundColor(.dealioTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .padding(.top, 8)
                        .padding(.bottom, bottomInset + 20)
                }
                .frame(minHeight: fullHeight)
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea()
        }
        .background(Color.white)
    }

    // MARK: Hero

    private func hero(topInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                DealioLogo(onDark: true)
                Spacer(minLength: 12)
                heroTrailing()
            }

            if step > 0 {
                Spacer().frame(height: 18)
                StepTrack(step: step, accentOnDark: accentOnDark)
            }

            Spacer().frame(height: step > 0 ? 20 : 36)

            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.system(size: 11, weight: .black))
                    .tracking(1.1)
                    .foregroundStyle(accentOnDark)
                Spacer().frame(height: 8)
            }

            Text(headline)
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.5)
                .foregroundColor(.white)

            Spacer().frame(height: 8)

            Text(subtitle)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.78))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: 20)

            HStack(spacing: 8) {
                TrustChip(text: "Free forever")
                TrustChip(text: "All roles")
                TrustChip(text: "RERA-ready")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 26)
        .padding(.top, topInset + 26)
        .padding(.bottom, 54)
        .background(
            ZStack {
                LinearGradient(
                    colors: [.dealioNavyDeep, .dealioNavyMid, .dealioTealDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // Teal glow orbs add depth and energy to the navy.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accentOnDark.opacity(0.38), .clear],
                            center: .center, startRadius: 0, endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(x: 150, y: -90)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accentOnDark.opacity(0.16), .clear],
                            center: .center, startRadius: 0, endRadius: 110
                        )
                    )
                    .frame(width: 220, height: 220)
                    .offset(x: -70, y: 60)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .clipShape(BottomRoundedShape(radius: 32))
        )
    }

    // MARK: Form card

    private var card: some View {
        VStack(alignment: .leading, spacing: 0, content: content)
            .padding(.horizontal, 22)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
            )
    }
}

extension AuthScaffold where HeroTrailing == EmptyView {
    /// For auth screens with nothing to put opposite the logo.
    init(
        headline: String,
        subtitle: String,
        eyebrow: String? = nil,
        accentOnDark: Color = .dealioTealBright,
        step: Int = 0,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(headline: headline, subtitle: subtitle, eyebrow: eyebrow,
                  accentOnDark: accentOnDark, step: step,
                  heroTrailing: { EmptyView() }, content: content)
    }
}
