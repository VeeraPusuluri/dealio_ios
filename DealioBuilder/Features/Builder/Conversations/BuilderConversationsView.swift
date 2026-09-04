import SwiftUI

/// The builder's inbox — the shared person-to-person messaging screen, told who
/// is looking at it. See `ConversationsView`.
struct BuilderConversationsView: View {
    var body: some View {
        ConversationsView(
            viewer: .builder,
            emptyHint: "When a channel partner introduces a buyer, your conversations with them appear here."
        )
    }
}
