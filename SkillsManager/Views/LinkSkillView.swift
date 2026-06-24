import SwiftUI

struct LinkSkillView: View {
    let projectURL: URL
    let alreadyLinkedNames: Set<String>
    let onLink: (SourceSkill) async -> Void
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var availableSkills: [SourceSkill] = []
    @State private var searchText = ""
    @State private var isLinking: Set<String> = []

    private var filteredSkills: [SourceSkill] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return availableSkills }
        return availableSkills.filter {
            $0.displayName.localizedCaseInsensitiveContains(trimmed) ||
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
            $0.description.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Link Skill to Project")
                        .font(.headline)
                    Text(projectURL.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            if availableSkills.isEmpty {
                emptySourceDirs
                    .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search skills...", text: $searchText)
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.05))

                    List {
                        ForEach(filteredSkills) { skill in
                            skillRow(skill)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .frame(width: 440, height: 460)
        .task {
            availableSkills = ProjectSymlinkService.scanSourceSkills()
        }
    }

    private var emptySourceDirs: some View {
        ContentUnavailableView(
            "No Source Skills Found",
            systemImage: "folder.badge.questionmark",
            description: Text("Configure skill source directories in Settings to browse available skills.")
        )
    }

    private func skillRow(_ skill: SourceSkill) -> some View {
        let alreadyLinked = alreadyLinkedNames.contains(skill.name)
        let linking = isLinking.contains(skill.name)

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(skill.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                    if alreadyLinked {
                        SkillMetaBadge(text: "Linked", tint: .green)
                    }
                }
                if !skill.description.isEmpty {
                    Text(skill.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(skill.sourceDirectory.path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if alreadyLinked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else if linking {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Link") {
                    isLinking.insert(skill.name)
                    Task {
                        await onLink(skill)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 6)
        .opacity(alreadyLinked ? 0.6 : 1.0)
    }
}
