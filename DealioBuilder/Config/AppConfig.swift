import Foundation

enum AppConfig {
    /// Base URL of the Dealio backend API.
    ///
    /// Points at the AWS **dealio-backend-dev** server (EC2 behind CloudFront, HTTPS).
    /// This is the same endpoint the Android debug build uses, so the simulator and a
    /// physical device both reach the live dev backend with no extra setup.
    ///
    /// For purely local development against a backend on this Mac, swap this for
    /// `http://localhost:8090/api` (the simulator shares the host network).
    static let apiBaseURL = URL(string: "https://d2l7qgxnnc8786.cloudfront.net/api")!

    /// Origin (scheme + host + port) used to resolve relative upload paths like `/uploads/x.jpg`.
    static var apiOrigin: String {
        var comps = URLComponents(url: apiBaseURL, resolvingAgainstBaseURL: false)!
        comps.path = ""
        comps.query = nil
        return comps.string ?? "http://localhost:8090"
    }

    /// Hosts that may legitimately be reached over plain HTTP (local dev backends).
    private static let cleartextHosts: Set<String> = ["localhost", "127.0.0.1", "10.0.2.2"]

    /// Resolves a backend asset path (cover image, document, …) to a loadable URL.
    ///
    /// Relative paths (`/uploads/...`) are prefixed with `apiOrigin`. Absolute URLs are
    /// kept as-is, except that remote `http://` URLs are upgraded to `https://` — the
    /// backend stores upload URLs with whatever scheme it saw at upload time (often plain
    /// HTTP), and CloudFront 301-redirects those to HTTPS. Upgrading up-front avoids the
    /// redirect round-trip and any cleartext/ATS blocking. Local dev hosts keep HTTP.
    static func resolveAssetURL(_ raw: String?) -> URL? {
        guard let raw, !raw.isEmpty else { return nil }
        let absolute = raw.hasPrefix("http") ? raw : apiOrigin + raw
        return URL(string: upgradeScheme(absolute))
    }

    private static func upgradeScheme(_ url: String) -> String {
        guard url.hasPrefix("http://") else { return url }
        let host = url.dropFirst("http://".count).prefix { $0 != "/" && $0 != ":" }
        return cleartextHosts.contains(String(host)) ? url : "https://" + url.dropFirst("http://".count)
    }

    /// Dealio brand teal (#0A7E8C).
    static let brandTealRGB = (red: 0.039, green: 0.494, blue: 0.553)
}
