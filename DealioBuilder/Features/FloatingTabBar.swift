import SwiftUI

/// One entry in a floating pill tab bar.
struct FloatingTabItem {
    let icon: String
    let label: String
}

/// Revolut-style floating pill tab bar shared by every role shell. Full-width
/// rounded capsule with the selected tab highlighted in teal; icons give a
/// springy bounce on tap.
struct FloatingTabBar: View {
    let items: [FloatingTabItem]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                FloatingTabPill(
                    icon: items[i].icon,
                    label: items[i].label,
                    selected: selection == i
                ) {
                    if selection != i {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = i }
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.14), radius: 16, x: 0, y: 6)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 1)
    }
}

private struct FloatingTabPill: View {
    let icon: String
    let label: String
    let selected: Bool
    let action: () -> Void

    /// Incremented on every tap to retrigger the symbol bounce.
    @State private var bump = 0

    var body: some View {
        Button {
            bump += 1
            action()
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if selected {
                        Capsule(style: .continuous)
                            .fill(Color.brandTeal.opacity(0.14))
                    }
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(selected ? Color.brandTeal : Color.dealioTextSecondary)
                        .symbolEffect(.bounce, value: bump)
                }
                .frame(width: 54, height: 32)

                Text(label)
                    .font(.system(size: 11, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.dealioNavy : Color.dealioTextSecondary)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Per-page chrome for shells that use `FloatingTabBar`: hides the system tab bar
/// so only our pill shows. Bottom space for the pill is reserved by the shell
/// laying the pill *below* the `TabView` in a `VStack` (see `FloatingTabShell`),
/// which reliably confines every screen — root and pushed — above the pill.
struct FloatingTabBarPage: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar(.hidden, for: .tabBar)
    }
}

/// Shell that stacks a `TabView` above the floating pill so tab content is
/// physically confined above it (no page ever scrolls under the pill), while the
/// top safe area is ignored so status-bar-filling heroes keep working.
struct FloatingTabShell<Content: View>: View {
    let items: [FloatingTabItem]
    @Binding var selection: Int
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
            FloatingTabBar(items: items, selection: $selection)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(Color.dealioMist)
    }
}
