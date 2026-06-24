import SwiftUI

struct ProjectSkillsView: View {
    let projectURL: URL?
    let projectSkills: [Skill]
    let linkedSkills: [Skill]
    let entryPointExists: Bool
    let isLoading: Bool
    @Binding var selectedSkill: Skill?
    let onPromote: (Skill) async -> Void
    let onLinkSkill: () -> Void
    let onUnlinkSkill: (Skill) async -> Void
    let onCreateEntryPoint: () async -> Void
    let onRemoveEntryPoint: () async -> Void

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Scanning project...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if projectSkills.isEmpty && linkedSkills.isEmpty {
                emptyState
            } else {
                List(selection: $selectedSkill) {
                    entryPointSection

                    if !linkedSkills.isEmpty {
                        Section("Linked Skills") {
                            ForEach(linkedSkills) { skill in
                                LinkedSkillRow(
                                    skill: skill,
                                    onUnlink: { Task { await onUnlinkSkill(skill) } }
                                )
                                .listRowSeparator(.hidden)
                                .tag(skill)
                            }
                        }
                    }

                    if !projectSkills.isEmpty {
                        Section("Project Skills") {
                            ForEach(projectSkills) { skill in
                                ProjectSkillRow(
                                    skill: skill,
                                    onPromote: { Task { await onPromote(skill) } }
                                )
                                .listRowSeparator(.hidden)
                                .tag(skill)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if projectURL != nil {
                HStack {
                    Button(action: onLinkSkill) {
                        Label("Link Skill", systemImage: "link")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.bar)
                .overlay(alignment: .top) { Divider() }
            }
        }
        .navigationTitle(projectURL.map { "Project: \($0.lastPathComponent)" } ?? "Project")
        .frame(minWidth: 260)
    }

    private var entryPointSection: some View {
        Group {
            if projectURL != nil {
                HStack(spacing: 8) {
                    if entryPointExists {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Entry point active")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(".claude/skills → .agents/skills")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospaced()
                        }
                        Spacer()
                        Button("Remove") {
                            Task { await onRemoveEntryPoint() }
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .font(.caption)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Entry point not set up")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("Claude Code won't discover linked skills")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Create") {
                            Task { await onCreateEntryPoint() }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .font(.caption)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(.bar)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .listRowSeparator(.hidden)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            projectURL == nil ? "No Project Open" : "No Skills Found",
            systemImage: projectURL == nil ? "folder" : "tray",
            description: Text(projectURL == nil
                ? "Click the folder button in the toolbar to open a project."
                : "No SKILL.md, .mdc, or linked skills found in this project.")
        )
    }
}

// MARK: - Project Skill Row

private struct ProjectSkillRow: View {
    let skill: Skill
    let onPromote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(skill.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                Spacer()
                Text(skill.filePath.pathExtension == "mdc" ? ".mdc" : "SKILL.md")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.1), in: Capsule())
            }
            if !skill.description.isEmpty {
                Text(skill.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Button(action: onPromote) {
                Label("Promote to Global", systemImage: "arrow.up.circle")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Linked Skill Row

private struct LinkedSkillRow: View {
    let skill: Skill
    let onUnlink: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text(skill.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                Spacer()
                SkillMetaBadge(text: "Linked", tint: .green)
            }
            if !skill.description.isEmpty {
                Text(skill.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text(skill.directoryPath.path)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
            Button(action: onUnlink) {
                Label("Unlink", systemImage: "link.badge.minus")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .tint(.red)
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    @Previewable @State var selected: Skill? = nil
    ProjectSkillsView(
        projectURL: URL(fileURLWithPath: "/Users/user/my-project"),
        projectSkills: [],
        linkedSkills: [],
        entryPointExists: false,
        isLoading: false,
        selectedSkill: $selected,
        onPromote: { _ in },
        onLinkSkill: {},
        onUnlinkSkill: { _ in },
        onCreateEntryPoint: {},
        onRemoveEntryPoint: {}
    )
    .frame(width: 300, height: 400)
}
