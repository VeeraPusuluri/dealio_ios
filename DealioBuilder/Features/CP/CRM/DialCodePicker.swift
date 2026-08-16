import SwiftUI

/// Picks a country dial code: the markets that actually come up first, the rest
/// of the world behind a search box.
struct DialCodePicker: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [DialCode] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return DIAL_CODES.filter {
            $0.label.localizedCaseInsensitiveContains(trimmed) || $0.code.contains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if results.isEmpty {
                    Section("Common") {
                        ForEach(COMMON_DIAL_CODES) { row($0) }
                    }
                    Section("All countries") {
                        ForEach(DIAL_CODES.filter { code in
                            !COMMON_DIAL_CODES.contains { $0.code == code.code && $0.label == code.label }
                        }) { row($0) }
                    }
                } else {
                    ForEach(results) { row($0) }
                }
            }
            .searchable(text: $query, prompt: "Country or code")
            .navigationTitle("Country code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func row(_ dial: DialCode) -> some View {
        Button {
            selection = dial.code
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Text(dial.flag).font(.title3)
                Text(dial.label).foregroundStyle(.primary)
                Spacer()
                Text(dial.code).foregroundStyle(.secondary)
                if dial.code == selection {
                    Image(systemName: "checkmark").foregroundStyle(.brandTeal)
                }
            }
        }
    }
}

/// The dial-code button + national-number field, sized for a `Form` row.
/// (`PhoneField` in `AuthComponents` is the same idea in the sign-in card's
/// chrome.)
struct ContactPhoneRow: View {
    @Binding var countryCode: String
    @Binding var phone: String
    var label: String = "Phone number"

    @State private var picking = false

    var body: some View {
        HStack(spacing: 10) {
            Button { picking = true } label: {
                HStack(spacing: 4) {
                    Text(flagFor(countryCode))
                    Text(countryCode).font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            TextField(label, text: $phone)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
        }
        .sheet(isPresented: $picking) {
            DialCodePicker(selection: $countryCode)
        }
    }
}
