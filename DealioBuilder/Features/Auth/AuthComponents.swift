import SwiftUI

// MARK: - Outlined field

/// A labelled, rounded-border input container matching the Android auth fields
/// (border turns teal and thickens while focused).
struct DealioField<Content: View>: View {
    let label: String
    var focused: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(focused ? .dealioTeal : .dealioTextSecondary)
            content()
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(focused ? Color.white : Color.dealioFieldFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(focused ? Color.dealioTeal : Color.dealioCardBorder,
                                lineWidth: focused ? 2 : 1)
                )
        }
    }
}

// MARK: - Phone field

/// Country code + phone number entry, like the web/Android login.
struct PhoneField: View {
    @Binding var countryCode: String
    @Binding var phone: String
    var enabled: Bool = true

    @FocusState private var focus: Field?
    private enum Field { case code, phone }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            DealioField(label: "Code", focused: focus == .code) {
                TextField("+91", text: $countryCode)
                    .keyboardType(.phonePad)
                    .focused($focus, equals: .code)
                    .onChange(of: countryCode) { _, new in
                        let filtered = String(new.prefix(5).filter { $0.isNumber || $0 == "+" })
                        if filtered != new { countryCode = filtered }
                    }
            }
            .frame(width: 96)

            DealioField(label: "Phone number", focused: focus == .phone) {
                TextField("9876543210", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .focused($focus, equals: .phone)
                    .onChange(of: phone) { _, new in
                        let filtered = String(new.prefix(15).filter { $0.isNumber })
                        if filtered != new { phone = filtered }
                    }
            }
        }
        .disabled(!enabled)
    }
}

// MARK: - OTP input

/// Six-box OTP entry. A real (near-invisible) text field sits over the boxes and
/// captures input; the boxes are a visual decoration of the current value.
struct OtpInput: View {
    @Binding var value: String
    var enabled: Bool = true

    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    let chars = Array(value)
                    let char = index < chars.count ? String(chars[index]) : ""
                    let active = enabled && focused && value.count == index
                    Text(char)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.dealioNavy)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(active ? Color.white : Color.dealioFieldFill))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(active ? Color.dealioTeal : Color.dealioCardBorder,
                                        lineWidth: active ? 2 : 1)
                        )
                }
            }

            TextField("", text: $value)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .foregroundColor(.clear)
                .tint(.clear)
                .accentColor(.clear)
                .opacity(0.02)
                .onChange(of: value) { _, new in
                    let filtered = String(new.prefix(6).filter { $0.isNumber })
                    if filtered != new { value = filtered }
                }
        }
        .disabled(!enabled)
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }
}

// MARK: - Primary button

/// Full-width navy primary button with a loading spinner state.
struct DealioButton: View {
    let title: String
    var loading: Bool = false
    var enabled: Bool = true
    let action: () -> Void

    private var isActive: Bool { enabled && !loading }

    private var fill: AnyShapeStyle {
        isActive
            ? AnyShapeStyle(LinearGradient(
                colors: [.dealioTeal, .dealioTealDeep],
                startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(Color.dealioButtonDisabled)
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if loading {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(isActive ? Color.white : Color.dealioTextSecondary)
            .shadow(color: isActive ? Color.dealioTeal.opacity(0.35) : .clear,
                    radius: 12, x: 0, y: 6)
        }
        .disabled(!enabled || loading)
    }
}

// MARK: - Error + dev-code helpers

struct AuthErrorText: View {
    let message: String?

    var body: some View {
        if let message, !message.isEmpty {
            Text(message)
                .font(.subheadline)
                .foregroundColor(.dealioError)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
    }
}

/// Dev-only chip: the backend echoes the OTP outside production — tap to fill.
struct DemoCodeHint: View {
    let demoCode: String?
    let onFill: (String) -> Void

    var body: some View {
        if let demoCode, !demoCode.isEmpty {
            Button { onFill(demoCode) } label: {
                Text("Dev code: \(demoCode) — tap to fill")
                    .font(.subheadline)
                    .foregroundColor(.dealioTextSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.dealioTeal.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.dealioTeal.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
    }
}

// MARK: - Chips

/// Translucent pill used in the hero to surface key selling points.
struct TrustChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Selectable role chip (Android `FilterChip` equivalent) for signup.
struct RoleChip: View {
    let label: String
    var color: Color = .dealioNavy
    let selected: Bool
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    selected ? color : Color.white,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .foregroundColor(selected ? .white : .dealioTextPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(selected ? Color.clear : Color.dealioCardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Flow layout (wrapping rows of chips)

/// A minimal wrapping layout — lays children left-to-right, wrapping to the next
/// row when the current one runs out of width. Used for the signup role chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth - spacing)
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
