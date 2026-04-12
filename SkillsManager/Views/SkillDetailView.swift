import SwiftUI
import AppKit

struct SkillDetailView: View {
    let skill: Skill?
    var onToggleStar: () -> Void = {}
    var onPromote: (Skill) async -> Void = { _ in }
    var onInstallToAgent: (Skill, [String]) async -> Void = { _, _ in }

    var body: some View {
        Group {
            if let skill {
                DetailContent(
                    skill: skill,
                    onToggleStar: onToggleStar,
                    // Fire-and-forget tasks: errors surface via SkillStore.errorMessage, not thrown here.
                    onPromote: { Task { await onPromote(skill) } },
                    onInstallToAgent: { agentIDs in Task { await onInstallToAgent(skill, agentIDs) } }
                )
            } else {
                placeholder
            }
        }
        .frame(minWidth: 320)
    }

    private var placeholder: some View {
        ContentUnavailableView(
            "Select a Skill",
            systemImage: "square.grid.2x2",
            description: Text("Choose a skill from the list to view its details.")
        )
    }
}

// MARK: - Detail content (extracted to keep body simple)

private struct DetailContent: View {
    let skill: Skill
    let onToggleStar: () -> Void
    let onPromote: () -> Void
    let onInstallToAgent: ([String]) -> Void

    @State private var showInstallToAgent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                metaRow
                actionRow
                agentTags
                Divider()
                markdownBody
            }
            .padding(20)
        }
        .sheet(isPresented: $showInstallToAgent) {
            InstallToAgentView(skill: skill, onInstall: onInstallToAgent)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(skill.displayName)
                .font(.largeTitle)
                .bold()
                .textSelection(.enabled)
            openInEditorButton
        }
    }

    private var openInEditorButton: some View {
        Button {
            NSWorkspace.shared.open(skill.filePath)
        } label: {
            Label("Open in Editor", systemImage: "square.and.pencil")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    // MARK: Meta row

    private var metaRow: some View {
        HStack(spacing: 8) {
            if let version = skill.version {
                SkillMetaBadge(text: "v\(version)")
            }
            sourceBadge
        }
    }

    private var sourceBadge: some View {
        let label: String
        switch skill.source {
        case .local:                          label = "Local"
        case .openClaw:                       label = "OpenClaw"
        case .symlinked:                      label = "Symlinked"
        case .plugin(let pluginSource, _):    label = pluginSource
        case .projectLocal:                   label = "Project"
        }
        return SkillMetaBadge(text: label)
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button {
                onToggleStar()
            } label: {
                Label(
                    skill.isStarred ? "Unstar" : "Star",
                    systemImage: skill.isStarred ? "star.fill" : "star"
                )
            }
            .buttonStyle(.bordered)
            .foregroundStyle(skill.isStarred ? .yellow : .secondary)

            if case .projectLocal = skill.source {
                Button {
                    onPromote()
                } label: {
                    Label("Promote to Global", systemImage: "arrow.up.circle")
                }
                .buttonStyle(.bordered)
            }

            Button {
                showInstallToAgent = true
            } label: {
                Label("Install to Agent…", systemImage: "square.and.arrow.down.on.square")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: Agent tags

    private var agentTags: some View {
        HStack(spacing: 6) {
            Image(systemName: "cpu")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(skill.compatibleAgents, id: \.self) { agent in
                SkillMetaBadge(text: agent)
            }
        }
    }

    // MARK: Markdown body

    private var markdownBody: some View {
        Group {
            if let attributed = try? AttributedString(
                markdown: skill.markdownContent,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                ),
                baseURL: nil
            ) {
                Text(attributed)
                    .textSelection(.enabled)
            } else {
                Text(skill.markdownContent)
                    .textSelection(.enabled)
            }
        }
        .font(.body)
        .frame(maxWidth: .infinity, alignment: .leading)
}
}

#if DEBUG
#Preview {
    SkillDetailView(skill: Skill.mockSkills.first)
        .frame(width: 500, height: 600)
}

#Preview("Empty") {
    SkillDetailView(skill: nil)
        .frame(width: 500, height: 600)
}
#endif
