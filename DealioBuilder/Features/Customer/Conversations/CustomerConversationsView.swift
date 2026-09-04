import SwiftUI

/// The buyer's inbox — the shared person-to-person messaging screen, told who is
/// looking at it. See `ConversationsView`.
struct CustomerConversationsView: View {
    var body: some View {
        ConversationsView(
            viewer: .customer,
            emptyHint: "Book a site visit to start talking to your builder and advisor."
        )
    }
}
