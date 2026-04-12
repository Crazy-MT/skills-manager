import SwiftUI

struct SkillMetaBadge: View {
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.10), in: Capsule())
    }
}

struct SkillCard<Badges: View, Actions: View>: View {
    let title: String
    let description: String
    @ViewBuilder let badges: Badges
    @ViewBuilder let actions: Actions

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(title)
                    .font(.body)
                    .bold()
                    .lineLimit(2)
                    .layoutPriority(1)

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    badges
                }
                .frame(alignment: .trailing)
            }

            if !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            actions
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.045) : Color.clear)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.14), lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: 8))
        .contentShape(.rect(cornerRadius: 8))
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}
