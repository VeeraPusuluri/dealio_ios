import SwiftUI
import UIKit

/// The pieces the partner's view of a project needs on top of the shared page.
///
/// The project sections themselves are the buyer's, verbatim — see
/// `CustomerProjectDetailView`, which takes a `viewer`. These are the two things
/// only a partner does with a project: hand it to someone, and turn a
/// conversation about it into a lead.

/// A share payload, wrapped so `.sheet(item:)` can drive the system share sheet.
struct ShareLinkPayload: Identifiable {
    let text: String
    var id: String { text }
}

/// The system share sheet.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Adding a lead from the project page — the project is already known, so only
/// the buyer has to be typed.
struct CPProjectAddLeadSheet: View {
    let projectName: String
    let working: Bool
    let onAdd: (String, String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""

    private var canSave: Bool {
        name.trimmedOrNil != nil && phone.filter(\.isNumber).count >= 6
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    Text(projectName).font(.subheadline.weight(.medium))
                }
                Section("The buyer") {
                    TextField("Full name", text: $name).textContentType(.name)
                    TextField("Phone", text: $phone).keyboardType(.phonePad)
                    TextField("Email (optional)", text: $email)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Add a lead")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let trimmed = name.trimmedOrNil else { return }
                        onAdd(trimmed, phone.filter(\.isNumber), email.trimmedOrNil)
                    }
                    .disabled(!canSave || working)
                }
            }
        }
    }
}
