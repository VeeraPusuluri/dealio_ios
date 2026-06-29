import SwiftUI
import UIKit

/// Small helpers for the share/contact actions used across the growth tools.
enum Share {
    /// `wa.me` deep link pre-filled with [text], optionally to a 10-digit Indian [phone].
    static func whatsAppURL(phone: String?, text: String) -> URL? {
        let digits = (phone ?? "").filter(\.isNumber)
        let to = digits.isEmpty ? "" : "91\(digits)"
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://wa.me/\(to)?text=\(encoded)")
    }

    static func telURL(_ phone: String) -> URL? {
        URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })")
    }

    static func copy(_ text: String) { UIPasteboard.general.string = text }
}
