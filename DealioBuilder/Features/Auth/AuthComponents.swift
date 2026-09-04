import SwiftUI

// MARK: - Outlined field

/// A labelled, rounded-border input container matching the Android auth fields
/// (border turns teal and thickens while focused, red when the value is wrong).
struct DealioField<Content: View>: View {
    let label: String
    var focused: Bool
    var icon: String? = nil
    var error: String? = nil
    @ViewBuilder var content: () -> Content

    private var borderColor: Color {
        if error != nil { return .dealioError }
        return focused ? .dealioTeal : .dealioCardBorder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(error != nil ? Color.dealioError
                                 : focused ? Color.dealioTeal : Color.dealioTextSecondary)

            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(focused ? Color.dealioTeal : Color.dealioTextSecondary)
                        .frame(width: 18)
                }
                content()
                    .tint(.dealioTeal)
                    .foregroundStyle(Color.dealioTextPrimary)
            }
            .padding(.horizontal, 14)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(focused ? Color.dealioSurface : Color.dealioFieldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(borderColor, lineWidth: focused || error != nil ? 2 : 1)
            )
            .animation(.easeOut(duration: 0.16), value: focused)
            .animation(.easeOut(duration: 0.16), value: error)

            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.dealioError)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Phone field

/// Country code + phone number entry, like the web/Android login.
struct PhoneField: View {
    @Binding var countryCode: String
    @Binding var phone: String
    var enabled: Bool = true
    /// Shown under the number once the person has left the field with a bad value.
    var error: String? = nil
    var onSubmit: (() -> Void)? = nil
    /// Reports focus loss so the caller can decide when to start validating.
    var onPhoneBlur: (() -> Void)? = nil

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
            .frame(width: 92)

            DealioField(label: "Phone number", focused: focus == .phone,
                        icon: "phone.fill", error: error) {
                TextField("9876543210", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .font(.body.weight(.medium))
                    .focused($focus, equals: .phone)
                    .submitLabel(.go)
                    .onSubmit { onSubmit?() }
                    .onChange(of: phone) { _, new in
                        let filtered = String(new.prefix(15).filter { $0.isNumber })
                        if filtered != new { phone = filtered }
                    }
            }
        }
        .disabled(!enabled)
        .onChange(of: focus) { was, _ in
            if was == .phone { onPhoneBlur?() }
        }
    }
}

// MARK: - OTP input

/// Six-box OTP entry. A real (near-invisible) text field sits over the boxes and
/// captures input; the boxes are a visual decoration of the current value.
///
/// The active box carries a blinking caret and lifts slightly, so the person can
/// see where the next digit lands — without it the six boxes read as decoration
/// and people tap each one in turn looking for a cursor.
struct OtpInput: View {
    @Binding var value: String
    var enabled: Bool = true
    var invalid: Bool = false
    /// Called the moment six digits are present, for hands-free verification.
    var onComplete: (() -> Void)? = nil

    @FocusState private var focused: Bool
    @State private var caretOn = true
    @State private var shake: CGFloat = 0

    private let caretTimer = Timer.publish(every: 0.55, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in box(index) }
            }

            TextField("", text: $value)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .opacity(0.02)
                .onChange(of: value) { old, new in
                    let filtered = String(new.prefix(6).filter { $0.isNumber })
                    if filtered != new { value = filtered; return }
                    // Auto-submit on the sixth digit — an OTP screen where the
                    // person still has to reach for a button is a step too many,
                    // and iOS's own autofill delivers all six at once.
                    if filtered.count == 6 && old.count < 6 { onComplete?() }
                }
        }
        .offset(x: shake)
        .disabled(!enabled)
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .onAppear { focused = true }
        .onReceive(caretTimer) { _ in caretOn.toggle() }
        .onChange(of: invalid) { _, isInvalid in
            guard isInvalid else { return }
            // A wrong code shakes the row: the error text below is easy to miss
            // when the eye is still on the boxes.
            withAnimation(.linear(duration: 0.06).repeatCount(5, autoreverses: true)) { shake = 7 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) { shake = 0 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Six digit verification code")
        .accessibilityValue(value.isEmpty ? "Empty" : value.map(String.init).joined(separator: " "))
    }

    private func box(_ index: Int) -> some View {
        let chars = Array(value)
        let char = index < chars.count ? String(chars[index]) : ""
        let active = enabled && focused && value.count == index
        let filled = !char.isEmpty

        return ZStack {
            if char.isEmpty && active && caretOn {
                Capsule()
                    .fill(Color.dealioTeal)
                    .frame(width: 2, height: 22)
            }
            Text(char)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.dealioTextPrimary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(active || filled ? Color.dealioSurface : Color.dealioFieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor(active: active, filled: filled),
                        lineWidth: active || invalid ? 2 : 1)
        )
        .shadow(color: active ? Color.dealioTeal.opacity(0.18) : .clear, radius: 6, y: 3)
        .scaleEffect(active ? 1.04 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: active)
        .animation(.easeOut(duration: 0.15), value: filled)
    }

    private func borderColor(active: Bool, filled: Bool) -> Color {
        if invalid { return .dealioError }
        if active { return .dealioTeal }
        return filled ? Color.dealioTeal.opacity(0.45) : .dealioCardBorder
    }
}

// MARK: - Primary button

/// Full-width teal primary button with loading and momentary success states.
struct DealioButton: View {
    let title: String
    var loading: Bool = false
    var enabled: Bool = true
    /// Swaps the label for a tick — set briefly after a successful verify so the
    /// screen confirms before the portal replaces it.
    var succeeded: Bool = false
    var successTitle: String = "Done"
    let action: () -> Void

    private var isTappable: Bool { enabled && !loading && !succeeded }

    private var fill: AnyShapeStyle {
        if succeeded { return AnyShapeStyle(Color.dealioStatusGreen) }
        return enabled && !loading
            ? AnyShapeStyle(LinearGradient(
                colors: [.dealioTealBright, .dealioTeal, .dealioTealDeep],
                startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(Color.dealioButtonDisabled)
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if succeeded {
                    Label(successTitle, systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .transition(.scale.combined(with: .opacity))
                } else if loading {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(fill, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .foregroundStyle(enabled || succeeded ? Color.white : Color.dealioTextSecondary)
            .shadow(color: enabled && !loading && !succeeded ? Color.dealioTeal.opacity(0.34) : .clear,
                    radius: 14, x: 0, y: 7)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: succeeded)
            .animation(.easeOut(duration: 0.18), value: loading)
        }
        .buttonStyle(.pressable)
        .disabled(!isTappable)
    }
}

// MARK: - Error + dev-code helpers

struct AuthErrorText: View {
    let message: String?

    var body: some View {
        if let message, !message.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.dealioError)
                Text(message)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.dealioError)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dealioError.opacity(0.09),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars").font(.caption2)
                    Text("Dev code \(demoCode) — tap to fill")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(Color.dealioTeal)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.dealioTeal.opacity(0.10), in: Capsule())
                .overlay(Capsule().stroke(Color.dealioTeal.opacity(0.30), lineWidth: 1))
            }
            .buttonStyle(.pressable)
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
        }
    }
}

// MARK: - Chips

/// Translucent pill used in the hero to surface key selling points.
struct TrustChip: View {
    let text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon).font(.system(size: 9, weight: .bold))
            }
            Text(text).font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(0.95))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.13), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1))
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
                    selected ? color : Color.dealioSurface,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .foregroundStyle(selected ? .white : Color.dealioTextPrimary)
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
