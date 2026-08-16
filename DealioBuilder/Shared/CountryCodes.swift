import Foundation

/// Dial codes a CP can pick from.
///
/// A contact's number is held as two pieces: the dial code and the national
/// number. They stay apart rather than being stored as one E.164 string because
/// lead matching and dedupe key on the bare national digits; folding "+971" into
/// the number would quietly break both.
///
/// The backend keeps the same list (`utils/phone.ts`) — it has to, because that
/// is what splits an imported "+33 6 12 34 56 78" into France rather than
/// assuming India and truncating it. Adding a country here without adding it
/// there leaves the number storable but not parseable on import.
struct DialCode: Identifiable, Hashable {
    let code: String
    let flag: String
    let label: String

    var id: String { code + label }

    init(_ code: String, _ flag: String, _ label: String) {
        self.code = code
        self.flag = flag
        self.label = label
    }
}

let DEFAULT_DIAL_CODE = "+91"

/// The markets that actually come up — India, the Gulf, and where NRI buyers
/// live. These lead the picker; `DIAL_CODES` carries the rest of the world
/// behind a search box.
let COMMON_DIAL_CODES: [DialCode] = [
    DialCode("+91", "🇮🇳", "India"),
    DialCode("+971", "🇦🇪", "UAE"),
    DialCode("+966", "🇸🇦", "Saudi Arabia"),
    DialCode("+974", "🇶🇦", "Qatar"),
    DialCode("+965", "🇰🇼", "Kuwait"),
    DialCode("+968", "🇴🇲", "Oman"),
    DialCode("+973", "🇧🇭", "Bahrain"),
    DialCode("+1", "🇺🇸", "US / Canada"),
    DialCode("+44", "🇬🇧", "UK"),
    DialCode("+65", "🇸🇬", "Singapore"),
    DialCode("+61", "🇦🇺", "Australia"),
    DialCode("+60", "🇲🇾", "Malaysia"),
    DialCode("+64", "🇳🇿", "New Zealand"),
    DialCode("+852", "🇭🇰", "Hong Kong"),
    DialCode("+49", "🇩🇪", "Germany"),
    DialCode("+353", "🇮🇪", "Ireland"),
    DialCode("+27", "🇿🇦", "South Africa"),
]

private let OTHER_DIAL_CODES: [DialCode] = [
    DialCode("+93", "🇦🇫", "Afghanistan"),
    DialCode("+355", "🇦🇱", "Albania"),
    DialCode("+213", "🇩🇿", "Algeria"),
    DialCode("+376", "🇦🇩", "Andorra"),
    DialCode("+244", "🇦🇴", "Angola"),
    DialCode("+54", "🇦🇷", "Argentina"),
    DialCode("+374", "🇦🇲", "Armenia"),
    DialCode("+297", "🇦🇼", "Aruba"),
    DialCode("+43", "🇦🇹", "Austria"),
    DialCode("+994", "🇦🇿", "Azerbaijan"),
    DialCode("+880", "🇧🇩", "Bangladesh"),
    DialCode("+375", "🇧🇾", "Belarus"),
    DialCode("+32", "🇧🇪", "Belgium"),
    DialCode("+501", "🇧🇿", "Belize"),
    DialCode("+229", "🇧🇯", "Benin"),
    DialCode("+975", "🇧🇹", "Bhutan"),
    DialCode("+591", "🇧🇴", "Bolivia"),
    DialCode("+387", "🇧🇦", "Bosnia & Herzegovina"),
    DialCode("+267", "🇧🇼", "Botswana"),
    DialCode("+55", "🇧🇷", "Brazil"),
    DialCode("+673", "🇧🇳", "Brunei"),
    DialCode("+359", "🇧🇬", "Bulgaria"),
    DialCode("+226", "🇧🇫", "Burkina Faso"),
    DialCode("+257", "🇧🇮", "Burundi"),
    DialCode("+855", "🇰🇭", "Cambodia"),
    DialCode("+237", "🇨🇲", "Cameroon"),
    DialCode("+238", "🇨🇻", "Cape Verde"),
    DialCode("+236", "🇨🇫", "Central African Republic"),
    DialCode("+235", "🇹🇩", "Chad"),
    DialCode("+56", "🇨🇱", "Chile"),
    DialCode("+86", "🇨🇳", "China"),
    DialCode("+57", "🇨🇴", "Colombia"),
    DialCode("+269", "🇰🇲", "Comoros"),
    DialCode("+242", "🇨🇬", "Congo"),
    DialCode("+243", "🇨🇩", "Congo (DRC)"),
    DialCode("+506", "🇨🇷", "Costa Rica"),
    DialCode("+225", "🇨🇮", "Côte d'Ivoire"),
    DialCode("+385", "🇭🇷", "Croatia"),
    DialCode("+53", "🇨🇺", "Cuba"),
    DialCode("+357", "🇨🇾", "Cyprus"),
    DialCode("+420", "🇨🇿", "Czechia"),
    DialCode("+45", "🇩🇰", "Denmark"),
    DialCode("+253", "🇩🇯", "Djibouti"),
    DialCode("+593", "🇪🇨", "Ecuador"),
    DialCode("+20", "🇪🇬", "Egypt"),
    DialCode("+503", "🇸🇻", "El Salvador"),
    DialCode("+240", "🇬🇶", "Equatorial Guinea"),
    DialCode("+291", "🇪🇷", "Eritrea"),
    DialCode("+372", "🇪🇪", "Estonia"),
    DialCode("+268", "🇸🇿", "Eswatini"),
    DialCode("+251", "🇪🇹", "Ethiopia"),
    DialCode("+679", "🇫🇯", "Fiji"),
    DialCode("+358", "🇫🇮", "Finland"),
    DialCode("+33", "🇫🇷", "France"),
    DialCode("+241", "🇬🇦", "Gabon"),
    DialCode("+220", "🇬🇲", "Gambia"),
    DialCode("+995", "🇬🇪", "Georgia"),
    DialCode("+233", "🇬🇭", "Ghana"),
    DialCode("+30", "🇬🇷", "Greece"),
    DialCode("+502", "🇬🇹", "Guatemala"),
    DialCode("+224", "🇬🇳", "Guinea"),
    DialCode("+592", "🇬🇾", "Guyana"),
    DialCode("+509", "🇭🇹", "Haiti"),
    DialCode("+504", "🇭🇳", "Honduras"),
    DialCode("+36", "🇭🇺", "Hungary"),
    DialCode("+354", "🇮🇸", "Iceland"),
    DialCode("+62", "🇮🇩", "Indonesia"),
    DialCode("+98", "🇮🇷", "Iran"),
    DialCode("+964", "🇮🇶", "Iraq"),
    DialCode("+972", "🇮🇱", "Israel"),
    DialCode("+39", "🇮🇹", "Italy"),
    DialCode("+81", "🇯🇵", "Japan"),
    DialCode("+962", "🇯🇴", "Jordan"),
    DialCode("+7", "🇰🇿", "Kazakhstan / Russia"),
    DialCode("+254", "🇰🇪", "Kenya"),
    DialCode("+996", "🇰🇬", "Kyrgyzstan"),
    DialCode("+856", "🇱🇦", "Laos"),
    DialCode("+371", "🇱🇻", "Latvia"),
    DialCode("+961", "🇱🇧", "Lebanon"),
    DialCode("+266", "🇱🇸", "Lesotho"),
    DialCode("+231", "🇱🇷", "Liberia"),
    DialCode("+218", "🇱🇾", "Libya"),
    DialCode("+423", "🇱🇮", "Liechtenstein"),
    DialCode("+370", "🇱🇹", "Lithuania"),
    DialCode("+352", "🇱🇺", "Luxembourg"),
    DialCode("+853", "🇲🇴", "Macau"),
    DialCode("+261", "🇲🇬", "Madagascar"),
    DialCode("+265", "🇲🇼", "Malawi"),
    DialCode("+960", "🇲🇻", "Maldives"),
    DialCode("+223", "🇲🇱", "Mali"),
    DialCode("+356", "🇲🇹", "Malta"),
    DialCode("+222", "🇲🇷", "Mauritania"),
    DialCode("+230", "🇲🇺", "Mauritius"),
    DialCode("+52", "🇲🇽", "Mexico"),
    DialCode("+373", "🇲🇩", "Moldova"),
    DialCode("+377", "🇲🇨", "Monaco"),
    DialCode("+976", "🇲🇳", "Mongolia"),
    DialCode("+382", "🇲🇪", "Montenegro"),
    DialCode("+212", "🇲🇦", "Morocco"),
    DialCode("+258", "🇲🇿", "Mozambique"),
    DialCode("+95", "🇲🇲", "Myanmar"),
    DialCode("+264", "🇳🇦", "Namibia"),
    DialCode("+977", "🇳🇵", "Nepal"),
    DialCode("+31", "🇳🇱", "Netherlands"),
    DialCode("+505", "🇳🇮", "Nicaragua"),
    DialCode("+227", "🇳🇪", "Niger"),
    DialCode("+234", "🇳🇬", "Nigeria"),
    DialCode("+389", "🇲🇰", "North Macedonia"),
    DialCode("+47", "🇳🇴", "Norway"),
    DialCode("+92", "🇵🇰", "Pakistan"),
    DialCode("+970", "🇵🇸", "Palestine"),
    DialCode("+507", "🇵🇦", "Panama"),
    DialCode("+675", "🇵🇬", "Papua New Guinea"),
    DialCode("+595", "🇵🇾", "Paraguay"),
    DialCode("+51", "🇵🇪", "Peru"),
    DialCode("+63", "🇵🇭", "Philippines"),
    DialCode("+48", "🇵🇱", "Poland"),
    DialCode("+351", "🇵🇹", "Portugal"),
    DialCode("+40", "🇷🇴", "Romania"),
    DialCode("+250", "🇷🇼", "Rwanda"),
    DialCode("+685", "🇼🇸", "Samoa"),
    DialCode("+378", "🇸🇲", "San Marino"),
    DialCode("+221", "🇸🇳", "Senegal"),
    DialCode("+381", "🇷🇸", "Serbia"),
    DialCode("+248", "🇸🇨", "Seychelles"),
    DialCode("+232", "🇸🇱", "Sierra Leone"),
    DialCode("+421", "🇸🇰", "Slovakia"),
    DialCode("+386", "🇸🇮", "Slovenia"),
    DialCode("+252", "🇸🇴", "Somalia"),
    DialCode("+82", "🇰🇷", "South Korea"),
    DialCode("+211", "🇸🇸", "South Sudan"),
    DialCode("+34", "🇪🇸", "Spain"),
    DialCode("+94", "🇱🇰", "Sri Lanka"),
    DialCode("+249", "🇸🇩", "Sudan"),
    DialCode("+597", "🇸🇷", "Suriname"),
    DialCode("+46", "🇸🇪", "Sweden"),
    DialCode("+41", "🇨🇭", "Switzerland"),
    DialCode("+963", "🇸🇾", "Syria"),
    DialCode("+886", "🇹🇼", "Taiwan"),
    DialCode("+992", "🇹🇯", "Tajikistan"),
    DialCode("+255", "🇹🇿", "Tanzania"),
    DialCode("+66", "🇹🇭", "Thailand"),
    DialCode("+228", "🇹🇬", "Togo"),
    DialCode("+216", "🇹🇳", "Tunisia"),
    DialCode("+90", "🇹🇷", "Türkiye"),
    DialCode("+993", "🇹🇲", "Turkmenistan"),
    DialCode("+256", "🇺🇬", "Uganda"),
    DialCode("+380", "🇺🇦", "Ukraine"),
    DialCode("+598", "🇺🇾", "Uruguay"),
    DialCode("+998", "🇺🇿", "Uzbekistan"),
    DialCode("+58", "🇻🇪", "Venezuela"),
    DialCode("+84", "🇻🇳", "Vietnam"),
    DialCode("+967", "🇾🇪", "Yemen"),
    DialCode("+260", "🇿🇲", "Zambia"),
    DialCode("+263", "🇿🇼", "Zimbabwe"),
]

let DIAL_CODES: [DialCode] = COMMON_DIAL_CODES + OTHER_DIAL_CODES

/// The flag for a dial code, or a globe when it is not one we carry.
func flagFor(_ code: String?) -> String {
    guard let code else { return "\u{1F310}" }
    return DIAL_CODES.first { $0.code == code }?.flag ?? "\u{1F310}"
}

/// Cleans a stored or typed dial code into "+NN" form, falling back to India.
func normalizeDialCode(_ raw: String?) -> String {
    guard let raw else { return DEFAULT_DIAL_CODE }
    let digits = raw.filter(\.isNumber)
    return digits.isEmpty ? DEFAULT_DIAL_CODE : "+" + digits
}

/// Splits a number that may carry its dial code into (code, national number).
///
/// Longest code first, so "+971" is not read as "+97". A number with no
/// recognisable code keeps `fallback` and is returned whole — better a contact
/// saved under the wrong country than one refused at the door.
func splitDialCode(_ raw: String, fallback: String = DEFAULT_DIAL_CODE) -> (code: String, number: String) {
    trySplitDialCode(raw, fallback: fallback) ?? (fallback, raw.filter(\.isNumber))
}

/// `splitDialCode`, but `nil` rather than a guess when nothing matches — for
/// import, where guessing wrong silently mangles the number.
func trySplitDialCode(_ raw: String, fallback: String = DEFAULT_DIAL_CODE) -> (code: String, number: String)? {
    let trimmed = raw.trimmingCharacters(in: .whitespaces)
    let digits = trimmed.filter(\.isNumber)
    guard !digits.isEmpty else { return nil }
    // Only a leading "+" or "00" means the code is actually present; a bare
    // ten-digit Indian mobile starting 91… is not "+9" followed by a number.
    let explicit = trimmed.hasPrefix("+") || trimmed.hasPrefix("00")
    guard explicit else { return nil }
    let normalized = trimmed.hasPrefix("00") ? String(digits.dropFirst(2)) : digits
    for candidate in DIAL_CODES.sorted(by: { $0.code.count > $1.code.count }) {
        let bare = candidate.code.dropFirst()
        if normalized.hasPrefix(bare) {
            return (candidate.code, String(normalized.dropFirst(bare.count)))
        }
    }
    return (fallback, normalized)
}

/// "+91 98765 43210" — how a number is read back to a person.
func formatPhone(_ countryCode: String?, _ phone: String) -> String {
    let code = normalizeDialCode(countryCode)
    let digits = phone.filter(\.isNumber)
    let grouped = digits.count == 10
        ? "\(digits.prefix(5)) \(digits.dropFirst(5))"
        : digits
    return "\(code) \(grouped)"
}

/// For wa.me and tel: links — "919876543210", no plus, no spaces.
func dialable(_ countryCode: String?, _ phone: String) -> String {
    normalizeDialCode(countryCode).dropFirst() + phone.filter(\.isNumber)
}

/// Whether two saved rows are the same person: the last ten digits of the number.
///
/// Two rows for one buyer rarely agree on formatting — one was typed with the
/// code folded in, the other imported with it split off — but they always agree
/// here. It is also the identity the server matches leads and invitees on.
func phoneIdentity(_ countryCode: String?, _ phone: String) -> String {
    String(dialable(countryCode, phone).suffix(10))
}
