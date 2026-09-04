import Foundation

// MARK: - UI-test harness
//
// The app talks to one live backend, so a UI test that signs in for real is
// neither fast nor repeatable — and half of what needs testing here is
// navigation, which needs *rows on screen* rather than a real network.
//
// Launching with `-uitest` swaps `URLSession.shared`'s transport for a stub that
// answers every `/api/...` call from fixtures below, and seeds a session for the
// role named by `-uitest-role`. Nothing in this file runs otherwise: `isActive`
// is read once, from launch arguments the App Store build never carries.

enum UITestSupport {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-uitest")
    }

    /// CUSTOMER / CP / BUILDER — which portal the test wants. `NONE` starts
    /// signed out, which is how the auth screens are reached.
    static var role: String {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-uitest-role"), index + 1 < args.count else {
            return "CUSTOMER"
        }
        return args[index + 1].uppercased()
    }

    private static var wantsSignedOut: Bool { role == "NONE" }

    private static var installed = false

    /// Answers every request from a fixture and seeds (or clears) the session.
    ///
    /// Called from `AuthStore.init`, which is the first thing that reads the
    /// defaults this writes — the app delegate's `didFinishLaunching` runs
    /// *after* the `App` struct's stored properties are initialised, so hooking
    /// it there left `AuthStore` reading the previous launch's session.
    static func installIfNeeded() {
        guard isActive, !installed else { return }
        installed = true
        URLProtocol.registerClass(StubURLProtocol.self)
        seedSession()
    }

    private static func seedSession() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: "dealio_app_lock_enabled")
        guard !wantsSignedOut else {
            defaults.removeObject(forKey: "dealio_access_token")
            defaults.removeObject(forKey: "dealio_refresh_token")
            defaults.removeObject(forKey: "dealio_user")
            defaults.removeObject(forKey: "dealio_builder_id")
            return
        }
        let user: [String: Any] = [
            "id": 1,
            "fullName": "Test \(role.capitalized)",
            "phone": "+919876543210",
            "role": role,
            "email": "test@dealio.test",
        ]
        defaults.set("uitest-token", forKey: "dealio_access_token")
        defaults.set(try? JSONSerialization.data(withJSONObject: user), forKey: "dealio_user")
        defaults.set(7, forKey: "dealio_builder_id")
    }
}

// MARK: - Stub transport

/// Intercepts every HTTP request the app makes and answers from `StubBackend`.
final class StubURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        UITestSupport.isActive && request.url?.scheme?.hasPrefix("http") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url ?? URL(string: "https://stub.invalid")!
        let body = StubBackend.body(for: url, method: request.httpMethod ?? "GET")
        let response = HTTPURLResponse(url: url, statusCode: 200,
                                       httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Fixtures

/// The smallest catalogue that still exercises every list the tests touch.
enum StubBackend {
    static func body(for url: URL, method: String) -> Data {
        let path = url.path
        let json: String

        switch true {
        case path.hasSuffix("/health"):
            return Data("{\"ok\":true}".utf8)

        // Customer
        case path.hasSuffix("/customer/cities"):
            json = #"["Hyderabad","Bengaluru"]"#
        case path.contains("/customer/projects/"):
            json = project(id: idSuffix(path) ?? 101, name: "Lakeside Habitat", featured: true)
        case path.hasSuffix("/customer/projects"), path.hasSuffix("/builder/projects"):
            json = "[\(project(id: 101, name: "Lakeside Habitat", featured: true)),"
                 + "\(project(id: 102, name: "Green Meadows", featured: false))]"
        case path.contains("/portal/customer/") || path.contains("/customer/"):
            json = "[]"

        // Builder
        case path.contains("/builder/") && path.contains("/projects/"):
            json = project(id: idSuffix(path) ?? 101, name: "Lakeside Habitat", featured: true)
        case path.contains("/builder/") && path.hasSuffix("/projects"):
            json = "[\(project(id: 101, name: "Lakeside Habitat", featured: true)),"
                 + "\(project(id: 102, name: "Green Meadows", featured: false))]"
        case path.contains("/builder/") && path.hasSuffix("/commissions"):
            json = """
            [{"id":"5001","projectName":"Lakeside Habitat","customerName":"Anita Rao",
              "saleValue":8500000,"commissionPercent":2.5,"amount":212500,"status":"Pending"},
             {"id":"5002","projectName":"Green Meadows","customerName":"Vikram Shah",
              "saleValue":6200000,"commissionPercent":2,"amount":124000,"status":"Released",
              "releasedDate":"2026-07-14"}]
            """
        case path.contains("/builder/") && path.hasSuffix("/deals"):
            json = """
            [{"id":9001,"status":"Booked","dealValue":8500000,"customerName":"Anita Rao",
              "projectName":"Lakeside Habitat","cpName":"Ravi Kumar","createdAt":"2026-06-01"},
             {"id":9002,"status":"Negotiation","dealValue":6200000,"customerName":"Vikram Shah",
              "projectName":"Green Meadows","cpName":"Ravi Kumar","createdAt":"2026-06-11"},
             {"id":9003,"status":"Site Visit","dealValue":4100000,"customerName":"Priya N",
              "projectName":"Lakeside Habitat","cpName":"Sunita Devi","createdAt":"2026-06-20"}]
            """
        case path.contains("/builder/") && path.hasSuffix("/leads"):
            json = """
            [{"id":"9001","customerName":"Anita Rao","phone":"9876500001",
              "projectName":"Lakeside Habitat","cpName":"Ravi Kumar","stage":"Booked",
              "source":"CP","budget":9000000,"dealValue":8500000,"createdAt":"2026-06-01",
              "daysInStage":3,"commissionStatus":"Pending"}]
            """
        case path.hasSuffix("/builder/ensure"):
            json = #"{"builderId":7}"#

        // CP
        case path.contains("/cp/") && path.hasSuffix("/profile"):
            json = """
            {"id":1,"fullName":"Test Cp","email":"test@dealio.test","phone":"+919876543210",
             "cp":{"city":"Hyderabad","tier":"Gold","totalDeals":3,"dealsThisMonth":1,
                   "totalEarnings":336500,"pendingCommission":212500,"influencerScore":72},
             "authorizedBuilders":[]}
            """
        case path.contains("/cp/") && path.hasSuffix("/leads"):
            json = """
            [{"id":9001,"projectId":101,"projectName":"Lakeside Habitat","customerName":"Anita Rao",
              "customerPhone":"9876500001","dealValue":8500000,"status":"Booked",
              "commissionStatus":"Pending","commissionPercent":2.5,"estimatedCommission":212500},
             {"id":9002,"projectId":102,"projectName":"Green Meadows","customerName":"Vikram Shah",
              "customerPhone":"9876500002","dealValue":6200000,"status":"Negotiation",
              "commissionStatus":"Pending","commissionPercent":2,"estimatedCommission":124000}]
            """
        case path.contains("/cp/") && path.hasSuffix("/commissions"):
            json = """
            [{"id":9001,"status":"Booked","dealValue":8500000,"commissionStatus":"Released",
              "commissionPercent":2.5,"commissionAmount":212500,"commissionReleasedAt":"2026-07-14",
              "customerName":"Anita Rao","projectName":"Lakeside Habitat","projectCity":"Hyderabad",
              "cpTier":"Gold"},
             {"id":9002,"status":"Negotiation","dealValue":6200000,"commissionStatus":"Pending",
              "commissionPercent":2,"commissionAmount":124000,
              "customerName":"Vikram Shah","projectName":"Green Meadows","projectCity":"Bengaluru",
              "cpTier":"Gold"}]
            """
        case path.contains("/cp/") && path.hasSuffix("/due-today"):
            json = #"{"meetings":[],"followUps":[],"callbacks":[]}"#
        case path.contains("/cp/") && path.hasSuffix("/contacts"):
            json = """
            [{"id":301,"name":"Anita Rao","countryCode":"+91","phone":"9876500001",
              "email":"anita@example.com","investment":900000,"createdAt":"2026-05-02"}]
            """
        case path.contains("/cp/") && path.contains("/deals/"):
            json = """
            {"id":9001,"projectId":101,"builderId":7,"status":"Booked","dealValue":8500000,
             "commissionStatus":"Released","cpAgreed":true,"customerConfirmed":true,
             "customerName":"Anita Rao","customerPhone":"9876500001",
             "projectName":"Lakeside Habitat","cpTier":"Gold","commissionPercent":2.5,
             "commissionAmount":212500,"dealDocuments":[],"events":[]}
            """

        default:
            // Anything not named above is a list the tests don't assert on.
            json = "[]"
        }

        return Data("{\"ok\":true,\"data\":\(json)}".utf8)
    }

    /// Trailing path component as an Int, for `/projects/101`-shaped routes.
    private static func idSuffix(_ path: String) -> Int? {
        Int(path.split(separator: "/").last ?? "")
    }

    private static func project(id: Int, name: String, featured: Bool) -> String {
        """
        {"id":\(id),"name":"\(name)","city":"Hyderabad","locality":"Gachibowli",
         "status":"UNDER_CONSTRUCTION","projectType":"APARTMENT","totalUnits":240,
         "availableUnits":86,"soldUnits":120,"bookedUnits":34,
         "priceMin":4500000,"priceMax":9500000,"imageUrl":null,
         "possessionDate":"Dec 2027","reraNumber":"P02400001234","published":true,
         "featured":\(featured),"closingSoon":false,"builderId":7,
         "configurations":["2BHK","3BHK"],"amenities":["Gym","Swimming Pool"],
         "builderName":"Prestige Group","builderYearEstablished":1986,
         "builderDeliveredProjects":42,"builderWebsite":"www.prestige.example",
         "builderAbout":"Three decades of residential development.",
         "reraExpiry":"2028-12-31","address":"Survey 42","pincode":"500032",
         "locationAdvantages":[
           {"category":"Corporate","name":"Hitec City","distanceKm":"6.5","driveMinutes":"15"},
           {"category":"Corporate","name":"Financial District","distanceKm":"2","driveMinutes":"6"},
           {"category":"Education","name":"Oakridge International","distanceKm":"3.2 km","driveMinutes":"9"},
           {"category":"Healthcare","name":"Continental Hospitals","distanceKm":"4","driveMinutes":"11"},
           {"category":"Transport","name":"Raidurg Metro","distanceKm":"5.5","driveMinutes":"14"},
           {"category":"Retail","name":"Inorbit Mall","distanceKm":"7","driveMinutes":"18"},
           {"category":"Leisure","name":"Botanical Garden","distanceKm":"4.8","driveMinutes":"12"}
         ]}
        """
    }
}
