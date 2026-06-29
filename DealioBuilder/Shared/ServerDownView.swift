import SwiftUI

@MainActor
final class ServerStatusMonitor: ObservableObject {
    @Published private(set) var isDown = false
    @Published private(set) var checking = true

    private let healthURL: URL = {
        let base = AppConfig.apiBaseURL.absoluteString.trimmingCharacters(in: .init(charactersIn: "/"))
        return URL(string: base + "/health")!
    }()

    private var pollTask: Task<Void, Never>?

    init() { startPolling() }

    private func startPolling() {
        pollTask = Task {
            while !Task.isCancelled {
                await ping()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func retry() {
        Task { await ping() }
    }

    private func ping() async {
        checking = true
        do {
            var request = URLRequest(url: healthURL, timeoutInterval: 5)
            request.httpMethod = "GET"
            let (_, response) = try await URLSession.shared.data(for: request)
            isDown = (response as? HTTPURLResponse)?.statusCode != 200
        } catch {
            isDown = true
        }
        checking = false
    }

    deinit { pollTask?.cancel() }
}

struct ServerDownView: View {
    @ObservedObject var monitor: ServerStatusMonitor

    @State private var spinAngle: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0B1B2E), Color(hex: 0x112E50)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Icon tile
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 88, height: 88)
                    Image(systemName: "cloud.slash.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.dealioOrange)
                }

                Spacer().frame(height: 28)

                Text("Server Unreachable")
                    .font(.title2.weight(.black))
                    .foregroundColor(.white)

                Spacer().frame(height: 12)

                Text("We can't connect to the Dealio server right now. This is usually temporary — please try again in a moment.")
                    .font(.subheadline)
                    .foregroundColor(.dealioTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)

                Spacer().frame(height: 36)

                Button {
                    monitor.retry()
                } label: {
                    HStack(spacing: 8) {
                        if monitor.checking {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .rotationEffect(.degrees(spinAngle))
                                .onAppear {
                                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                        spinAngle = 360
                                    }
                                }
                        }
                        Text(monitor.checking ? "Checking…" : "Try again")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 160, height: 52)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0xF97316), Color(hex: 0xEA580C)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
                .disabled(monitor.checking)

                Spacer().frame(height: 24)

                Label("Retrying automatically every 15 seconds", systemImage: "wifi.slash")
                    .font(.caption)
                    .foregroundColor(.dealioTextSecondary.opacity(0.6))
            }
        }
    }
}
