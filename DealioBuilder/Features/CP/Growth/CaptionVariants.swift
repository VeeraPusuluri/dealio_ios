import Foundation

/// Caption generation for the Content Studio.
///
/// A caption is built from three inputs the CP chooses: the `OfferType` (what is
/// actually on the table), the platform (how it is written), and the tone (who it
/// is written for). The offer supplies the substance — its headline, terms and
/// follow-up ask — while the platform composer decides the shape and the tone
/// decides the angle.
///
/// A CP posting the same project to a family group and to a LinkedIn feed needs
/// two different posts, so we never hand back a single "the" caption. Every
/// generate produces one caption per tone and the CP picks the angle that fits.
///
/// Nothing here is commission-facing: these captions are written to be forwarded
/// to buyers. Mirrors Android's `ui/cp/growth/CaptionVariants.kt`.

/// The angle a caption takes. Same facts, different audience.
struct CaptionTone: Identifiable, Hashable {
    let id: String
    let label: String
    let blurb: String
}

/// One generated option — the tone it was written in, and the copy itself.
struct CaptionVariant: Identifiable {
    let tone: CaptionTone
    let text: String
    var id: String { tone.id }
}

let captionTones = [
    CaptionTone(id: "lifestyle", label: "Lifestyle", blurb: "Warm and aspirational — families and end-users"),
    CaptionTone(id: "investor", label: "Investor", blurb: "Facts and numbers — buyers doing the math"),
    CaptionTone(id: "urgency", label: "Urgency", blurb: "Short and punchy — stories and quick posts"),
]

/// Three captions for `offer` on `platform`, one per tone.
///
/// `seed` rotates the hook, offer-term and follow-up pools, so "Regenerate" gives
/// genuinely different copy rather than the same sentence with a different emoji.
func captionVariants(project: Project, offer: OfferType, platform: String, seed: Int) -> [CaptionVariant] {
    let facts = CaptionFacts(project)
    return captionTones.map { tone in
        CaptionVariant(tone: tone, text: compose(facts, offer, platform, tone.id, seed))
    }
}

// MARK: - Facts

/// Every project field a caption might mention, pre-cleaned so blanks read as absent.
private struct CaptionFacts {
    let name: String
    let builder: String?
    let city: String?
    let location: String
    let configs: String?
    let price: String?
    let amenities: String?
    let possession: String?
    let status: String?
    let rera: String?
    let tag: String

    init(_ project: Project) {
        name = project.name.nilIfEmpty ?? "This project"
        builder = project.builderName?.nilIfEmpty
        city = project.city?.nilIfEmpty
        location = project.whereLine
        configs = (project.configurations ?? []).filter { !$0.isEmpty }.nilIfEmpty?.joined(separator: " / ")
        price = project.priceLow.map { Fmt.compactPrice($0) }
        amenities = (project.amenities ?? []).filter { !$0.isEmpty }.prefix(3).nilIfEmpty?.joined(separator: " · ")
        possession = project.possessionDate?.nilIfEmpty.map { Fmt.date($0) }
        status = project.status?.nilIfEmpty.map { Fmt.titleCase($0) }
        rera = project.reraNumber?.nilIfEmpty
        tag = (project.city ?? "India").filter { $0.isLetter || $0.isNumber }
    }
}

private extension Collection {
    /// Nil for an empty collection, so `?.joined()` reads as "absent" downstream.
    var nilIfEmpty: Self? { isEmpty ? nil : self }
}

/// Rotates through a pool by seed, wrapping negatives.
private func pick(_ pool: [String], _ seed: Int) -> String {
    guard !pool.isEmpty else { return "" }
    return pool[((seed % pool.count) + pool.count) % pool.count]
}

/// Drops the lines whose underlying field was missing, so a sparse project still
/// reads well, then collapses the runs of blank lines that leaves behind.
private func lines(_ parts: String?...) -> String {
    parts.compactMap { $0 }.joined(separator: "\n")
        .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Hook pools

private func lifestyleHook(_ seed: Int) -> String {
    pick([
        "Space to grow into — not out of.",
        "The kind of address you stop explaining and just say the name of.",
        "Mornings by the clubhouse, evenings home before the traffic starts.",
        "A home your family grows into over the next twenty years.",
    ], seed)
}

private func investorHook(_ facts: CaptionFacts, _ seed: Int) -> String {
    pick([
        "Entry pricing today in a corridor that is still being built out.",
        "Clean title, a developer with a delivery record, and a realistic payment plan.",
        "The numbers on this one hold up — worth five minutes of your time.",
        "Rental demand in \(facts.city ?? "the micro-market") is running ahead of new supply.",
    ], seed)
}

private func urgencyHook(_ seed: Int) -> String {
    pick([
        "The best inventory always goes in the first few weeks.",
        "A handful of units left in the launch price band.",
        "Prices revise as the tower fills up — this is the lowest it gets.",
        "Two floors released this week. They will not last the month.",
    ], seed)
}

// MARK: - Offer block

/// The part of the caption that is about the deal rather than the building: a
/// badge, the offer framed for this audience, and two of its terms. `bold` wraps
/// the badge in WhatsApp's asterisks.
private func offerBlock(_ offer: OfferType, _ tone: String, _ seed: Int, bold: Bool = false) -> String {
    let badge = bold ? "*\(offer.badge)*" : offer.badge
    let terms = (0..<min(2, offer.points.count)).map { "• " + pick(offer.points, seed + $0) }
    return (["\(offer.emoji) \(badge)", offer.angle(tone)] + terms).joined(separator: "\n")
}

/// What the CP is offering to send back, phrased to sit after "send you" / "share".
private func ask(_ offer: OfferType, _ seed: Int) -> String { pick(offer.asks, seed) }

// MARK: - Platform composers

private func compose(_ f: CaptionFacts, _ o: OfferType, _ platform: String,
                     _ tone: String, _ seed: Int) -> String {
    switch platform {
    case "instagram": return instagram(f, o, tone, seed)
    case "facebook": return facebook(f, o, tone, seed)
    case "linkedin": return linkedin(f, o, tone, seed)
    default: return whatsapp(f, o, tone, seed)
    }
}

private func whatsapp(_ f: CaptionFacts, _ o: OfferType, _ tone: String, _ seed: Int) -> String {
    switch tone {
    case "investor":
        return lines(
            "📊 *\(f.name)* — the numbers",
            f.location.nilIfEmpty.map { "📍 \($0)" },
            "",
            offerBlock(o, tone, seed, bold: true),
            "",
            f.price.map { "• Entry from \($0)" },
            f.configs.map { "• Configurations: \($0)" },
            f.possession.map { "• Possession: \($0)" },
            f.status.map { "• Status: \($0)" },
            f.rera.map { "• RERA: \($0)" },
            "",
            investorHook(f, seed),
            "",
            "Reply here and I'll send you \(ask(o, seed))."
        )
    case "urgency":
        return lines(
            "⚡ *\(f.name)*",
            [f.configs, f.price.map { "from \($0)" }].compactMap { $0 }.joined(separator: " · ").nilIfEmpty,
            f.location.nilIfEmpty.map { "📍 \($0)" },
            "",
            offerBlock(o, tone, seed, bold: true),
            "",
            urgencyHook(seed),
            "",
            "Reply today and I'll send you \(ask(o, seed))."
        )
    default:
        return lines(
            "🏡 *\(f.name)*" + (f.builder.map { " by \($0)" } ?? ""),
            f.location.nilIfEmpty.map { "📍 \($0)" },
            "",
            lifestyleHook(seed),
            "",
            offerBlock(o, tone, seed, bold: true),
            "",
            f.configs.map { "🛏 \($0)" },
            f.price.map { "💰 Starting \($0)" },
            f.possession.map { "🗓 Possession \($0)" },
            f.amenities.map { "✨ \($0)" },
            "",
            "Reply here and I'll send you \(ask(o, seed))."
        )
    }
}

private func instagram(_ f: CaptionFacts, _ o: OfferType, _ tone: String, _ seed: Int) -> String {
    let tags: String
    switch tone {
    case "investor": tags = "\(o.hashtag) #RealEstateInvestment #\(f.tag) #PropertyInvestment #RealEstateIndia"
    case "urgency": tags = "\(o.hashtag) #\(f.tag)Property #LimitedUnits #RealEstateIndia"
    default: tags = "\(o.hashtag) #\(f.tag)RealEstate #\(f.tag)Homes #DreamHome #RealEstateIndia"
    }
    let dm = "DM \"\(o.keyword)\" and I'll send you \(ask(o, seed))"

    switch tone {
    case "investor":
        return lines(
            "📈 \(investorHook(f, seed))", "",
            f.name, f.location.nilIfEmpty, "",
            offerBlock(o, tone, seed), "",
            f.price.map { "• Ticket size from \($0)" },
            f.configs.map { "• \($0)" },
            f.possession.map { "• Possession \($0)" },
            f.rera.map { "• RERA \($0)" },
            "", "\(dm) 📊", "", tags
        )
    case "urgency":
        return lines(
            "⚡ \(urgencyHook(seed))", "",
            f.name + (f.location.nilIfEmpty.map { " — \($0)" } ?? ""),
            [f.price.map { "From \($0)" }, f.configs].compactMap { $0 }.joined(separator: " · ").nilIfEmpty,
            "", offerBlock(o, tone, seed), "", "\(dm) 🔑", "", tags
        )
    default:
        return lines(
            "✨ \(lifestyleHook(seed))", "",
            "🏡 \(f.name)" + (f.configs.map { " — \($0)" } ?? ""),
            f.location.nilIfEmpty.map { "📍 \($0)" },
            f.price.map { "💰 Starting \($0)" },
            f.amenities.map { "✨ \($0)" },
            "", offerBlock(o, tone, seed), "", "\(dm) 🔑", "", tags
        )
    }
}

private func facebook(_ f: CaptionFacts, _ o: OfferType, _ tone: String, _ seed: Int) -> String {
    let comment = "Comment \"\(o.keyword)\" or message me and I'll share \(ask(o, seed))."
    switch tone {
    case "investor":
        return lines(
            "📊 Investment snapshot — \(f.name)" + (f.location.nilIfEmpty.map { ", \($0)" } ?? ""),
            "", investorHook(f, seed), "", offerBlock(o, tone, seed), "",
            f.price.map { "💰 Entry from \($0)" },
            f.configs.map { "🏗️ \($0)" },
            f.possession.map { "🗓️ Possession \($0)" },
            f.builder.map { "🏢 Developed by \($0)" },
            f.rera.map { "✅ RERA \($0)" },
            "", comment, "", "\(o.hashtag) #RealEstateInvestment #\(f.tag)"
        )
    case "urgency":
        return lines(
            "⚡ \(f.name) — \(urgencyHook(seed))", "",
            [f.location.nilIfEmpty.map { "📍 \($0)" },
             f.price.map { "💰 From \($0)" },
             f.configs.map { "🏗️ \($0)" }].compactMap { $0 }.joined(separator: "\n").nilIfEmpty,
            "", offerBlock(o, tone, seed), "", comment, "", "\(o.hashtag) #\(f.tag)Homes"
        )
    default:
        return lines(
            "🏠 Introducing \(f.name)" + (f.builder.map { " by \($0)" } ?? ""),
            "", lifestyleHook(seed), "", offerBlock(o, tone, seed), "",
            f.location.nilIfEmpty.map { "📍 \($0)" },
            f.configs.map { "🏗️ \($0)" },
            f.price.map { "💰 Starting \($0)" },
            f.amenities.map { "✨ \($0)" },
            f.possession.map { "🗓️ Possession \($0)" },
            "", comment, "", "\(o.hashtag) #\(f.tag)Homes #RealEstate"
        )
    }
}

private func linkedin(_ f: CaptionFacts, _ o: OfferType, _ tone: String, _ seed: Int) -> String {
    switch tone {
    case "investor":
        return lines(
            "Investment note — \(f.name)" + (f.location.nilIfEmpty.map { ", \($0)" } ?? "") + ".",
            "", investorHook(f, seed), "", offerBlock(o, tone, seed), "",
            f.price.map { "• Entry ticket: \($0)" },
            f.configs.map { "• Configurations: \($0)" },
            f.possession.map { "• Possession: \($0)" },
            f.builder.map { "• Developer: \($0)" },
            f.rera.map { "• RERA: \($0)" },
            "", "Happy to share \(ask(o, seed)) with anyone evaluating the corridor.",
            "", "\(o.hashtag) #RealEstateInvestment #\(f.tag) #PropertyMarket"
        )
    case "urgency":
        return lines(
            "Availability update — \(f.name)" + (f.location.nilIfEmpty.map { ", \($0)" } ?? "") + ".",
            "", urgencyHook(seed), "", offerBlock(o, tone, seed), "",
            [f.price.map { "Starting \($0)" }, f.configs].compactMap { $0 }.joined(separator: " · ").nilIfEmpty,
            "", "If you or someone in your network is evaluating \(f.city ?? "the market") right now, I can send across \(ask(o, seed)).",
            "", "\(o.hashtag) #RealEstate #\(f.tag)"
        )
    default:
        return lines(
            "\(f.name)" + (f.builder.map { " by \($0)" } ?? "") + " is now open for site visits"
                + (f.location.nilIfEmpty.map { " in \($0)" } ?? "") + ".",
            "", lifestyleHook(seed), "", offerBlock(o, tone, seed), "",
            f.configs.map { "• Configurations: \($0)" },
            f.price.map { "• Starting price: \($0)" },
            f.possession.map { "• Possession: \($0)" },
            f.status.map { "• Status: \($0)" },
            f.rera.map { "• RERA: \($0)" },
            "", "Reach out if you would like \(ask(o, seed)) or a site visit arranged.",
            "", "\(o.hashtag) #RealEstate #\(f.tag) #Housing"
        )
    }
}
