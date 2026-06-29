import SwiftUI

/// Launch splash, ported from the Android app's `ui/screens/SplashScreen.kt`:
/// a navy gradient with ambient corner glows, a pulsing halo behind the Dealio
/// mark, a staggered entrance for the wordmark + tagline, and a loading-dots
/// footer. Calls `onFinished` after the same ~2.1s the Android screen waits.
struct SplashView: View {
    var onFinished: () -> Void

    /// Flips true on appear to drive the staggered entrance animations.
    @State private var visible = false
    /// Continuous ambient pulse for the halo + loading dots.
    @State private var glow = false

    var body: some View {
        ZStack {
            // Navy gradient base.
            LinearGradient(
                colors: [.dealioNavyDeep, Color(hex: 0x0E2542), .dealioNavyMid],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ambientGlows

            // Center brand stack.
            VStack(spacing: 0) {
                ZStack {
                    // Pulsing halo sitting behind the mark.
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.dealioTealBright.opacity(0.45), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 95
                            )
                        )
                        .frame(width: 190, height: 190)
                        .opacity(visible ? (glow ? 0.8 : 0.35) : 0)
                        .animation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true), value: glow)
                        .animation(.easeInOut(duration: 0.7), value: visible)

                    DealioMark(size: 96)
                        .opacity(visible ? 1 : 0)
                        .scaleEffect(visible ? 1 : 0.82)
                        .animation(.easeInOut(duration: 0.7), value: visible)
                }

                Spacer().frame(height: 24)

                (Text("Deal").foregroundColor(.white)
                    + Text("io").foregroundColor(.dealioTealBright))
                    .font(.system(size: 40, weight: .bold))
                    .tracking(-1)
                    .opacity(visible ? 1 : 0)
                    .offset(y: visible ? 0 : 18)
                    .animation(.easeInOut(duration: 0.6).delay(0.22), value: visible)

                Spacer().frame(height: 10)

                Text("Real estate made simple")
                    .font(.system(size: 15))
                    .tracking(0.5)
                    .foregroundColor(.white.opacity(0.65))
                    .opacity(visible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5).delay(0.45), value: visible)
            }

            // Footer: copyright.
            VStack(spacing: 20) {
                Spacer()
                Text("© 2026 Dealio · Free forever for all roles")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.bottom, 40)
            .opacity(visible ? 1 : 0)
            .animation(.easeInOut(duration: 0.5).delay(0.65), value: visible)
        }
        .onAppear {
            visible = true
            glow = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) { onFinished() }
        }
    }

    /// Two soft radial glows in opposite corners give the flat navy some depth.
    private var ambientGlows: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.dealioTeal.opacity(0.22), .clear],
                            center: .center, startRadius: 0, endRadius: 180
                        )
                    )
                    .frame(width: 360, height: 360)
                    .position(x: 50, y: 30)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.dealioTealBright.opacity(0.16), .clear],
                            center: .center, startRadius: 0, endRadius: 210
                        )
                    )
                    .frame(width: 420, height: 420)
                    .position(x: geo.size.width - 40, y: geo.size.height - 20)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    SplashView(onFinished: {})
}
