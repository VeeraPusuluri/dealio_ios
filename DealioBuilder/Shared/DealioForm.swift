import SwiftUI

// MARK: - Form design system
//
// A Material-inspired outlined field set, used by every hand-built Dealio form
// (the CP contact editor, the builder project wizard, the auth screens).
//
// The pieces exist because SwiftUI's `Form` gives a label *or* a placeholder but
// never both, has nowhere to put a per-field error, and cannot show a field as
// invalid. Those three are the whole difference between "the save button is
// greyed out and I don't know why" and a form that says which line is wrong.

// MARK: Tokens

enum DealioMetrics {
    static let fieldHeight: CGFloat = 56
    static let fieldRadius: CGFloat = 14
    static let cardRadius: CGFloat = 18
    static let gutter: CGFloat = 16
}

// MARK: - Validation

/// A field's live validation state.
///
/// `pristine` is not the same as `valid`: a required field the user has not
/// reached yet must not be shouting in red. Errors surface once a field has been
/// touched (focused then left) or once the form has been submitted, which is the
/// rule `DealioTextField` applies.
struct FieldValidation {
    var error: String?
    var isValid: Bool { error == nil }

    static let valid = FieldValidation(error: nil)
    static func invalid(_ message: String) -> FieldValidation { .init(error: message) }

    // Common rules, so the same phrasing is used everywhere.

    static func required(_ value: String, _ label: String) -> FieldValidation {
        value.trimmedOrNil == nil ? .invalid("\(label) is required") : .valid
    }

    static func phone(_ value: String, required: Bool = true) -> FieldValidation {
        let digits = value.filter(\.isNumber)
        if digits.isEmpty { return required ? .invalid("Phone number is required") : .valid }
        if digits.count < 6 { return .invalid("That number looks too short") }
        if digits.count > 15 { return .invalid("That number looks too long") }
        return .valid
    }

    static func email(_ value: String, required: Bool = false) -> FieldValidation {
        guard let trimmed = value.trimmedOrNil else {
            return required ? .invalid("Email is required") : .valid
        }
        // Deliberately loose: the only email that matters is one the server can
        // post to, and a regex tighter than this rejects real addresses.
        let parts = trimmed.split(separator: "@")
        guard parts.count == 2, !parts[0].isEmpty, parts[1].contains("."),
              !parts[1].hasPrefix("."), !parts[1].hasSuffix("."), !trimmed.contains(" ") else {
            return .invalid("That doesn't look like an email address")
        }
        return .valid
    }

    static func number(_ value: String, _ label: String, required: Bool = true,
                       min: Double? = nil, max: Double? = nil) -> FieldValidation {
        guard let trimmed = value.trimmedOrNil else {
            return required ? .invalid("\(label) is required") : .valid
        }
        guard let number = Double(trimmed.replacingOccurrences(of: ",", with: "")) else {
            return .invalid("\(label) must be a number")
        }
        if let min, number < min { return .invalid("\(label) must be at least \(Self.trim(min))") }
        if let max, number > max { return .invalid("\(label) must be \(Self.trim(max)) or less") }
        return .valid
    }

    static func exactDigits(_ value: String, _ count: Int, _ label: String,
                            required: Bool = true) -> FieldValidation {
        let digits = value.filter(\.isNumber)
        if digits.isEmpty { return required ? .invalid("\(label) is required") : .valid }
        return digits.count == count ? .valid : .invalid("\(label) must be \(count) digits")
    }

    static func url(_ value: String) -> FieldValidation {
        guard let trimmed = value.trimmedOrNil else { return .valid }
        let normalised = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let parsed = URL(string: normalised), parsed.host?.contains(".") == true else {
            return .invalid("That doesn't look like a web address")
        }
        return .valid
    }

    private static func trim(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(value))" : "\(value)"
    }
}

// MARK: - Outlined text field

/// A Material-style outlined text field: persistent label above the box, an
/// optional leading icon, a focus ring, and a helper line under the box that
/// turns into the error when there is one.
///
/// The error only shows once the field has been touched or `showError` is forced
/// on by a submit, so an untouched form is calm rather than red.
struct DealioTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var icon: String? = nil
    var helper: String? = nil
    var validation: FieldValidation = .valid
    /// Set by the form on submit, to reveal errors on fields never focused.
    var forceError: Bool = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var capitalization: TextInputAutocapitalization = .sentences
    var autocorrect: Bool = true
    var multiline: Bool = false
    var lineLimit: ClosedRange<Int> = 1...4
    var required: Bool = false
    var enabled: Bool = true
    /// Trailing accessory (a unit suffix, a picker button, a clear control).
    var suffix: String? = nil

    @FocusState private var focused: Bool
    @State private var touched = false

    private var showsError: Bool { !validation.isValid && (touched || forceError) }

    private var borderColor: Color {
        if showsError { return .dealioError }
        return focused ? .dealioTeal : .dealioCardBorder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(showsError ? Color.dealioError
                                     : focused ? Color.dealioTeal : Color.dealioTextSecondary)
                if required {
                    Text("*").font(.caption.weight(.semibold)).foregroundStyle(Color.dealioError)
                }
            }
            .animation(.easeOut(duration: 0.15), value: focused)

            HStack(alignment: multiline ? .top : .center, spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(focused ? Color.dealioTeal : Color.dealioTextSecondary)
                        .frame(width: 20)
                        .padding(.top, multiline ? 2 : 0)
                }
                Group {
                    if multiline {
                        TextField(placeholder.isEmpty ? label : placeholder,
                                  text: $text, axis: .vertical)
                            .lineLimit(lineLimit)
                    } else {
                        TextField(placeholder.isEmpty ? label : placeholder, text: $text)
                    }
                }
                .font(.body)
                .foregroundStyle(Color.dealioTextPrimary)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled(!autocorrect)
                .focused($focused)
                .tint(.dealioTeal)

                if let suffix, !suffix.isEmpty {
                    Text(suffix)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.dealioTextSecondary)
                } else if !text.isEmpty && focused && !multiline {
                    Button { text = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.dealioTextSecondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear \(label)")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, multiline ? 14 : 0)
            .frame(minHeight: multiline ? DealioMetrics.fieldHeight : DealioMetrics.fieldHeight)
            .background(
                RoundedRectangle(cornerRadius: DealioMetrics.fieldRadius, style: .continuous)
                    .fill(enabled ? (focused ? Color.dealioSurface : Color.dealioFieldFill)
                          : Color.dealioButtonDisabled.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DealioMetrics.fieldRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: focused || showsError ? 2 : 1)
            )
            .animation(.easeOut(duration: 0.15), value: focused)
            .animation(.easeOut(duration: 0.15), value: showsError)

            if showsError, let message = validation.error {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.dealioError)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else if let helper, !helper.isEmpty {
                Text(helper)
                    .font(.caption2)
                    .foregroundStyle(Color.dealioTextSecondary)
            }
        }
        .disabled(!enabled)
        .onChange(of: focused) { wasFocused, isFocused in
            // Touched means "left", not "entered" — validating mid-typing would
            // mark every phone number invalid at the first digit.
            if wasFocused && !isFocused { touched = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label + (required ? ", required" : ""))
        .accessibilityValue(text.isEmpty ? "Empty" : text)
    }
}

// MARK: - Outlined picker

/// The same outlined box as `DealioTextField`, wrapping a menu picker. Keeps
/// dropdowns visually on the same grid as text inputs, which a `Form`'s inline
/// `Picker` does not.
struct DealioPickerField<T: Hashable>: View {
    let label: String
    @Binding var selection: T
    let options: [T]
    let title: (T) -> String
    var icon: String? = nil
    var helper: String? = nil
    var required: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(Color.dealioTextSecondary)
                if required {
                    Text("*").font(.caption.weight(.semibold)).foregroundStyle(Color.dealioError)
                }
            }
            Menu {
                Picker(label, selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text(title(option)).tag(option)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.dealioTextSecondary)
                            .frame(width: 20)
                    }
                    Text(title(selection))
                        .font(.body)
                        .foregroundStyle(Color.dealioTextPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.dealioTextSecondary)
                }
                .padding(.horizontal, 14)
                .frame(height: DealioMetrics.fieldHeight)
                .background(
                    RoundedRectangle(cornerRadius: DealioMetrics.fieldRadius, style: .continuous)
                        .fill(Color.dealioFieldFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DealioMetrics.fieldRadius, style: .continuous)
                        .stroke(Color.dealioCardBorder, lineWidth: 1)
                )
            }
            .accessibilityLabel(label)
            .accessibilityValue(title(selection))

            if let helper, !helper.isEmpty {
                Text(helper).font(.caption2).foregroundStyle(Color.dealioTextSecondary)
            }
        }
    }
}

// MARK: - Form section card

/// A titled card that groups related fields. Replaces `Form`'s `Section`, which
/// cannot carry an icon, a subtitle, or a per-section completeness marker.
struct DealioFormSection<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var tint: Color = .brandTeal
    /// Shows a green tick in the header once the section's required fields pass.
    var complete: Bool? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 11) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(tintGradient(tint),
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.dealioTextPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(Color.dealioTextSecondary)
                    }
                }
                Spacer(minLength: 0)
                if let complete {
                    Image(systemName: complete ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.system(size: 16))
                        .foregroundStyle(complete ? Color.dealioStatusGreen : Color.dealioTextSecondary.opacity(0.5))
                        .accessibilityLabel(complete ? "Section complete" : "Section incomplete")
                }
            }

            VStack(alignment: .leading, spacing: 14) { content() }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dealioSurface,
                    in: RoundedRectangle(cornerRadius: DealioMetrics.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DealioMetrics.cardRadius, style: .continuous)
                .strokeBorder(Color.dealioCardBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Buttons

/// The press-scale every Dealio tap target uses, so a card, a chip and a button
/// all answer a finger the same way.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

/// Full-width primary action with loading and "not ready yet" states.
///
/// `ready: false` dims the button but leaves it **tappable**. A greyed-out,
/// unresponsive submit is the worst thing a long form can do: the one gesture a
/// person makes to find out what is wrong is the gesture it refuses. Tapping a
/// dimmed button runs the action, which is what reveals the errors.
struct DealioPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var loading = false
    /// Whether the form validates. Appearance only — see the note above.
    var ready = true
    /// Genuinely disabled (mid-submit, offline). Refuses the tap.
    var enabled = true
    var tint: Color = .dealioTeal
    let action: () -> Void

    private var looksActive: Bool { ready && !loading }

    var body: some View {
        Button(action: action) {
            ZStack {
                if loading {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 8) {
                        if let systemImage {
                            Image(systemName: systemImage).font(.subheadline.weight(.semibold))
                        }
                        Text(title).font(.headline)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                looksActive
                    ? AnyShapeStyle(LinearGradient(colors: [tint, tint.opacity(0.82)],
                                                   startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(Color.dealioButtonDisabled),
                in: RoundedRectangle(cornerRadius: DealioMetrics.fieldRadius, style: .continuous)
            )
            .foregroundStyle(looksActive ? Color.white : Color.dealioTextSecondary)
            .shadow(color: looksActive ? tint.opacity(0.32) : .clear, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.pressable)
        .disabled(!enabled || loading)
    }
}

// MARK: - Sticky save bar

/// The bar a long form ends with: a summary of what is still missing, then the
/// action. Pinned above the keyboard so nobody scrolls back up to find out why
/// the form will not save.
struct DealioSaveBar: View {
    let title: String
    /// The first thing blocking a save, shown above the button.
    var problem: String?
    var loading = false
    /// Whether the form currently validates — dims the button, never blocks it.
    var ready = true
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if let problem, !problem.isEmpty {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.dealioError)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
            DealioPrimaryButton(title: title, loading: loading, ready: ready, action: action)
        }
        .padding(.horizontal, DealioMetrics.gutter)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .animation(.snappy, value: problem)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.dealioCardBorder).frame(height: 0.5)
        }
    }
}

// MARK: - Screen scaffolding

/// The standard page ground. One place to change, rather than 40 screens each
/// naming their own colour.
extension View {
    func dealioPageBackground(_ color: Color = .dealioMist) -> some View {
        background(color.ignoresSafeArea())
    }
}
