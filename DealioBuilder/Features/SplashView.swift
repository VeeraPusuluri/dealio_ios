import SwiftUI
import Lottie

/// Launch splash — plays the designed "Dealio Splash" Lottie animation
/// (`dealio_splash.json` in the bundle): the app mark assembles, the wordmark
/// builds in, and the "Find your next deal" tagline wipes in over a navy
/// backdrop. Calls `onFinished` when the clip finishes (with a safety timeout
/// so the app never sticks on the splash if the animation can't load).
struct SplashView: View {
    var onFinished: () -> Void

    var body: some View {
        ZStack {
            // Matches the animation's own navy background so there's no flash
            // before the first frame paints.
            Color.dealioNavyDeep.ignoresSafeArea()

            LottieSplash(name: "dealio_splash", onFinished: onFinished)
                .ignoresSafeArea()
        }
        .onAppear {
            // Safety net: the JSON is ~2.5s at 60fps; if the completion handler
            // never fires (missing/broken asset), advance anyway.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { onFinished() }
        }
    }
}

/// Thin `UIViewRepresentable` wrapper around Lottie's `LottieAnimationView`,
/// playing the named bundle animation once and calling `onFinished` on complete.
private struct LottieSplash: UIViewRepresentable {
    let name: String
    let onFinished: () -> Void

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        let animationView = LottieAnimationView(name: name)
        animationView.contentMode = .scaleAspectFill
        animationView.loopMode = .playOnce
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        var didFinish = false
        animationView.play { _ in
            guard !didFinish else { return }
            didFinish = true
            onFinished()
        }
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

#Preview {
    SplashView(onFinished: {})
}
