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
struct AuthScaffold<Content: View>: View {
    let headline: String
    let subtitle: String
    @ViewBuilder var content: () -> Content

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
            DealioLogo(onDark: true)

            Spacer().frame(height: 36)

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
                    colors: [.dealioNavyDeep, .dealioNavyMid, .dealioNavyPrimary],
                    startPoint: .top,
                    endPoint: .bottom
                )
                // Teal glow orbs add depth to the flat navy.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.dealioTealBright.opacity(0.24), .clear],
                            center: .center, startRadius: 0, endRadius: 130
                        )
                    )
                    .frame(width: 260, height: 260)
                    .offset(x: 150, y: -90)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.dealioTealBright.opacity(0.10), .clear],
                            center: .center, startRadius: 0, endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
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
