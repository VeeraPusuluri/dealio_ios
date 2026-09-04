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

/// The two steps every auth screen walks through.
enum AuthPhase { case details, verify }

/// Branded shell for the auth screens: a navy hero lit by slowly drifting teal
/// and amber orbs, carrying the Dealio mark, a step indicator and the headline,
/// flowing into a floating form card that overlaps the hero.
///
/// The hero is deliberately generous — this is the one screen a person sees
/// before they have any reason to trust the product, so it carries the brand at
/// full strength rather than being a thin bar over a form.
struct AuthScaffold<Content: View>: View {
    let headline: String
    let subtitle: String
    /// Which of the two steps is showing, for the progress rail. Nil hides it.
    var phase: AuthPhase? = nil
    /// Pulls the caller back a step from the hero's own control.
    var onBack: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    @State private var drift = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                        .offset(y: -34)

                    Spacer(minLength: 8)

                    footer
                        .padding(.bottom, bottomInset + 18)
                }
                .frame(minHeight: fullHeight)
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea()
        }
        .background(Color.dealioMist)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }

    // MARK: Hero

    private func hero(topInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                DealioLogo(onDark: true)
                Spacer()
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(.white.opacity(0.14), in: Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Go back")
                    .transition(.scale.combined(with: .opacity))
                }
            }

            if let phase {
                Spacer().frame(height: 26)
                stepRail(phase)
            }

            Spacer().frame(height: phase == nil ? 34 : 22)

            Text(headline)
                .font(.system(size: 32, weight: .heavy))
                .tracking(-0.8)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)

            Spacer().frame(height: 9)

            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.80))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: 22)

            HStack(spacing: 8) {
                TrustChip(text: "Free forever", icon: "sparkles")
                TrustChip(text: "All roles", icon: "person.2.fill")
                TrustChip(text: "RERA-ready", icon: "checkmark.seal.fill")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 26)
        .padding(.top, topInset + 20)
        .padding(.bottom, 58)
        .background(heroBackground.clipShape(BottomRoundedShape(radius: 34)))
        .animation(.snappy, value: headline)
    }

    /// Two-segment progress rail. A person mid-OTP can see they are one step from
    /// done, and that the code screen is not a dead end.
    private func stepRail(_ phase: AuthPhase) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { index in
                let reached = index == 0 || phase == .verify
                Capsule()
                    .fill(reached ? Color.dealioTealBright : Color.white.opacity(0.22))
                    .frame(width: index == 0 ? 26 : 26, height: 4)
            }
            Text(phase == .details ? "Step 1 of 2" : "Step 2 of 2")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.leading, 2)
        }
        .animation(.snappy, value: phase)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(phase == .details ? "Step 1 of 2" : "Step 2 of 2")
    }

    /// Navy base with drifting glow orbs. The motion is slow enough to read as
    /// depth rather than animation, and is switched off under Reduce Motion.
    private var heroBackground: some View {
        ZStack {
            LinearGradient(
                colors: [.dealioNavyDeep, .dealioNavyMid, .dealioTealDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(RadialGradient(colors: [Color.dealioTealBright.opacity(0.42), .clear],
                                     center: .center, startRadius: 0, endRadius: 160))
                .frame(width: 320, height: 320)
                .offset(x: drift ? 130 : 165, y: drift ? -70 : -105)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            Circle()
                .fill(RadialGradient(colors: [Color.dealioOrange.opacity(0.22), .clear],
                                     center: .center, startRadius: 0, endRadius: 120))
                .frame(width: 240, height: 240)
                .offset(x: drift ? -50 : -80, y: drift ? 40 : 75)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            Circle()
                .fill(RadialGradient(colors: [Color.dealioTeal.opacity(0.28), .clear],
                                     center: .center, startRadius: 0, endRadius: 110))
                .frame(width: 200, height: 200)
                .offset(x: drift ? 20 : -20, y: drift ? 20 : -10)
        }
        .allowsHitTesting(false)
    }

    // MARK: Form card

    private var card: some View {
        VStack(alignment: .leading, spacing: 0, content: content)
            .padding(.horizontal, 22)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.dealioSurface)
                    .shadow(color: .black.opacity(0.14), radius: 20, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.dealioCardBorder.opacity(0.7), lineWidth: 0.5)
            )
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.dealioTeal)
                Text("Your number is only used to sign you in.")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.dealioTextSecondary)
            }
            Text("By continuing you agree to our Terms & Privacy Policy.")
                .font(.caption2)
                .foregroundStyle(Color.dealioTextSecondary.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 30)
    }
}
