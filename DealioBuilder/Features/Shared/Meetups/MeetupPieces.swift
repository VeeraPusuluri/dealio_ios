import SwiftUI

/// The shared visual pieces of a meetup — hero, chips, RSVP summary.
///
/// Both the organiser's screens and the buyer's draw from this set, so an event
/// looks like the same event whichever side of the app you are on.

/// The banner at the top of an event.
///
/// A photograph when the organiser supplied one, and the category wash when they
/// did not. Plenty of meetups will never have a cover — a partner arranging a
/// site visit from a car park has no picture to hand — so the fallback is a
/// designed state rather than an apology: the tint says what kind of thing this
/// is before you have read a word.
struct MeetupHero<Content: View>: View {
    let category: MeetupCategory
    var height: CGFloat = 116
    var coverImage: String?
    /// Only comes out for a photograph. Over the flat wash it would darken a
    /// colour that was chosen, and anything on the gradient already has contrast.
    var scrim = false
    @ViewBuilder var content: () -> Content

    init(category: MeetupCategory, height: CGFloat = 116, coverImage: String? = nil,
         scrim: Bool = false, @ViewBuilder content: @escaping () -> Content = { EmptyView() }) {
        self.category = category; self.height = height
        self.coverImage = coverImage; self.scrim = scrim; self.content = content
    }

    var body: some View {
        ZStack {
            category.gradient
            if let url = AppConfig.resolveAssetURL(coverImage) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: category.icon)
                        .font(.system(size: height * 0.4))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                if scrim {
                    // Bottom-weighted, so a title on the photograph stays
                    // readable without flattening the top half of the picture.
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.10), location: 0.45),
                        .init(color: .black.opacity(0.62), location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                }
            } else {
                Image(systemName: category.icon)
                    .font(.system(size: height * 0.4))
                    .foregroundStyle(.white.opacity(0.3))
            }
            content()
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
    }
}

struct MeetupDetailLine: View {
    let icon: String
    let text: String
    var lineLimit: Int = 2

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.dealioTextSecondary)
                .frame(width: 15)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Color.dealioTextPrimary)
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

/// A category badge — icon plus name, in the category's own colour.
struct CategoryChip: View {
    let category: MeetupCategory

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: category.icon).font(.system(size: 11))
            Text(category.label).font(.caption).fontWeight(.semibold).lineLimit(1)
        }
        .foregroundStyle(category.tint)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(category.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct RsvpPill: View {
    let rsvp: Rsvp

    var body: some View {
        Text(rsvp.label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(rsvp.tint)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(rsvp.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

/// Who can see this — the one control a partner most needs to be sure about.
struct VisibilityChip: View {
    let isPublic: Bool
    let city: String?

    var body: some View {
        let tint: Color = isPublic ? .green : .dealioTextSecondary
        HStack(spacing: 5) {
            Image(systemName: isPublic ? "globe" : "lock").font(.system(size: 10))
            Text(isPublic ? "Open to \(city?.nilIfEmpty ?? "your city")" : "Invite only")
                .font(.caption).fontWeight(.semibold).lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// "12 going · 3 maybe · 5 no reply".
///
/// Zero-count parts are dropped rather than shown as "0 maybe" — the line exists
/// to be read at a glance, and padding it with nothing to report makes it slower
/// to read, not more informative.
struct RsvpSummary: View {
    let going: Int
    let maybe: Int
    let noReply: Int
    var font: Font = .caption

    private var parts: [(Rsvp, String)] {
        var result: [(Rsvp, String)] = []
        if going > 0 { result.append((.going, "\(going) going")) }
        if maybe > 0 { result.append((.maybe, "\(maybe) maybe")) }
        if noReply > 0 { result.append((.invited, "\(noReply) no reply")) }
        return result
    }

    var body: some View {
        if parts.isEmpty {
            Text("Nobody invited yet").font(font).foregroundStyle(Color.dealioTextSecondary)
        } else {
            HStack(spacing: 5) {
                ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                    if index > 0 {
                        Text("·").font(font).foregroundStyle(Color.dealioTextSecondary)
                    }
                    Circle().fill(part.0.tint).frame(width: 6, height: 6)
                    Text(part.1).font(font).fontWeight(.medium)
                        .foregroundStyle(Color.dealioTextPrimary)
                }
            }
        }
    }
}
