import SwiftUI

/// The small caps heading over a group of fields in the auth card.
struct FieldGroupLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .black))
            .tracking(1)
            .foregroundStyle(Color.dealioTextSecondary)
    }
}

/// Compact horizontally-scrolling role pills, for where the picker is a filter
/// on an otherwise short form (sign in). The selected pill fills with the role's
/// colour so the choice is unmissable next to four muted neighbours.
struct RolePillRow: View {
    let roles: [DealioRole]
    @Binding var selected: DealioRole
    var enabled = true

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(roles) { role in
                    pill(role, isSelected: role.value == selected.value)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    private func pill(_ role: DealioRole, isSelected: Bool) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) { selected = role }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: role.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : role.color)
                Text(role.shortLabel)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .white : Color.dealioTextSecondary)
            }
            .padding(.leading, 12).padding(.trailing, 15)
            .padding(.vertical, 9)
            .background(isSelected ? role.color : Color.dealioFieldFill, in: Capsule())
            .overlay {
                if !isSelected { Capsule().strokeBorder(Color.dealioCardBorder, lineWidth: 1) }
            }
            // A hair of lift on the active pill — enough to separate it from the
            // row without the chips looking like they're floating away.
            .scaleEffect(isSelected ? 1.04 : 1)
            .shadow(color: role.color.opacity(isSelected ? 0.32 : 0), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.55)
    }
}

/// Full-width role rows with a one-line description of what each account gets.
/// Used at sign-up, where picking the wrong type is expensive to undo and the
/// extra height buys real clarity.
struct RoleCardList: View {
    let roles: [DealioRole]
    @Binding var selected: DealioRole
    var enabled = true

    var body: some View {
        VStack(spacing: 8) {
            ForEach(roles) { role in
                card(role, isSelected: role.value == selected.value)
            }
        }
    }

    private func card(_ role: DealioRole, isSelected: Bool) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) { selected = role }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: role.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : role.color)
                    .frame(width: 38, height: 38)
                    .background(isSelected ? role.color : role.color.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(role.label)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Color.dealioNavy)
                    Text(role.tagline)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.dealioTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                selectionDot(isSelected: isSelected, color: role.color)
            }
            .padding(.horizontal, 12).padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? role.color.opacity(0.07) : Color.dealioFieldFill,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected ? role.color.opacity(0.55) : Color.dealioCardBorder,
                              lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.55)
    }

    /// Radio-style affordance: an empty ring until picked, then a filled tick.
    private func selectionDot(isSelected: Bool, color: Color) -> some View {
        ZStack {
            Circle().fill(isSelected ? color : .clear)
            Circle().strokeBorder(isSelected ? color : Color.dealioCardBorder, lineWidth: 1.5)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 21, height: 21)
    }
}

/// Small tinted pill naming the active role — sits in the auth hero.
struct RoleHeroChip: View {
    let role: DealioRole
    let accentOnDark: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(accentOnDark).frame(width: 7, height: 7)
            Text(role.shortLabel)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.leading, 10).padding(.trailing, 13)
        .padding(.vertical, 7)
        .background(.white.opacity(0.10), in: Capsule())
        .overlay(Capsule().strokeBorder(accentOnDark.opacity(0.45), lineWidth: 1))
    }
}

/// Two-segment progress track showing details → verify.
struct StepTrack: View {
    let step: Int
    var totalSteps = 2
    let accentOnDark: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                let done = index < step
                Capsule()
                    .fill(done ? accentOnDark : Color.white.opacity(0.18))
                    .frame(width: done ? 28 : 16, height: 4)
            }
        }
        .animation(.snappy(duration: 0.25), value: step)
    }
}

/// Inline "you're on the wrong pill" correction, offered after a role mismatch.
struct SwitchRoleAction: View {
    let role: DealioRole
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: role.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                Text("Continue as \(role.label)")
                    .font(.system(size: 13.5, weight: .semibold))
                Spacer(minLength: 0)
                Image(systemName: "arrow.right").font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(role.color)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(role.color.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(role.color.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
