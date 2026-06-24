import Foundation

/// Scans source directories for available skills and manages symlinks inside a project's
/// `.agents/skills/` directory, plus the `.claude/skills` → `.agents/skills` entry-point symlink.
enum ProjectSymlinkService {

    // MARK: - Source directories

    static func skillSourceDirectories(defaults: UserDefaults = .standard) -> [URL] {
        let paths = defaults.stringArray(forKey: AppSettings.skillSourceDirectoriesKey) ?? []
        return paths.compactMap { path in
            let url = URL(fileURLWithPath: path)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
                return nil
            }
            return url
        }
    }

    static func saveSourceDirectories(_ urls: [URL], defaults: UserDefaults = .standard) {
        defaults.set(urls.map { $0.path }, forKey: AppSettings.skillSourceDirectoriesKey)
    }

    // MARK: - Source skill scanning

    static func scanSourceSkills() -> [SourceSkill] {
        var results: [SourceSkill] = []
        let fm = FileManager.default
        for sourceDir in skillSourceDirectories() {
            // Check if sourceDir itself is a skill directory (contains SKILL.md directly)
            if let skill = buildSourceSkill(dir: sourceDir, fm: fm) {
                results.append(skill)
            }

            // Also scan subdirectories (for repos containing multiple skills)
            guard let entries = try? fm.contentsOfDirectory(
                at: sourceDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for entry in entries {
                if let skill = buildSourceSkill(dir: entry, fm: fm) {
                    results.append(skill)
                }
            }
        }
        results.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        return results
    }

    private static func buildSourceSkill(dir: URL, fm: FileManager) -> SourceSkill? {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { return nil }
        let skillMD = dir.appendingPathComponent("SKILL.md")
        guard fm.fileExists(atPath: skillMD.path),
              let content = try? String(contentsOf: skillMD, encoding: .utf8) else { return nil }
        let parsed = SkillParser.parse(content: content)
        let name = dir.lastPathComponent
        let displayName = parsed.frontmatter["name"] ?? name
        let description = parsed.frontmatter["description"] ?? ""
        return SourceSkill(
            name: name,
            displayName: displayName,
            description: description,
            sourceDirectory: dir
        )
    }

    // MARK: - Linked skill detection

    static func linkedSkillNames(in projectURL: URL) -> Set<String> {
        let agentsDir = projectURL.appendingPathComponent(".agents/skills")
        let fm = FileManager.default
        guard fm.fileExists(atPath: agentsDir.path) else { return [] }
        guard let entries = try? fm.contentsOfDirectory(
            at: agentsDir,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var names = Set<String>()
        for entry in entries {
            // Only count valid symlinks whose targets still exist
            guard let dest = try? fm.destinationOfSymbolicLink(atPath: entry.path) else { continue }
            let resolved: URL
            if dest.hasPrefix("/") {
                resolved = URL(fileURLWithPath: dest)
            } else {
                resolved = entry.deletingLastPathComponent().appendingPathComponent(dest)
            }
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: resolved.path, isDirectory: &isDir), isDir.boolValue else { continue }
            names.insert(entry.lastPathComponent)
        }
        return names
    }

    // MARK: - Entry point (.claude/skills → .agents/skills)

    static func entryPointExists(in projectURL: URL) -> Bool {
        let entryPoint = projectURL.appendingPathComponent(".claude/skills")
        let fm = FileManager.default
        guard let dest = try? fm.destinationOfSymbolicLink(atPath: entryPoint.path) else { return false }
        // Accept both ".agents/skills" and "../.agents/skills" relative forms, and absolute paths ending in "/.agents/skills"
        if dest == ".agents/skills" || dest == "../.agents/skills" { return true }
        let resolvedDest: URL
        if dest.hasPrefix("/") {
            resolvedDest = URL(fileURLWithPath: dest)
        } else {
            resolvedDest = entryPoint.deletingLastPathComponent().appendingPathComponent(dest)
        }
        let expected = projectURL.appendingPathComponent(".agents/skills")
        return resolvedDest.standardized.path == expected.standardized.path
    }

    static func createEntryPoint(in projectURL: URL) throws {
        let fm = FileManager.default
        let entryPoint = projectURL.appendingPathComponent(".claude/skills")

        // Ensure .claude/ exists
        let claudeDir = entryPoint.deletingLastPathComponent()
        if !fm.fileExists(atPath: claudeDir.path) {
            try fm.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        }

        // Remove existing entry at path
        if fm.fileExists(atPath: entryPoint.path) {
            try fm.removeItem(at: entryPoint)
        }

        // Relative symlink: .claude/skills → ../.agents/skills
        try fm.createSymbolicLink(atPath: entryPoint.path, withDestinationPath: "../.agents/skills")
    }

    static func removeEntryPoint(in projectURL: URL) throws {
        let entryPoint = projectURL.appendingPathComponent(".claude/skills")
        let fm = FileManager.default
        if fm.fileExists(atPath: entryPoint.path) {
            try fm.removeItem(at: entryPoint)
        }
    }

    // MARK: - Symlink operations

    static func linkSkill(named name: String, from sourceDir: URL, to projectURL: URL) throws {
        let fm = FileManager.default
        let agentsDir = projectURL.appendingPathComponent(".agents/skills")
        if !fm.fileExists(atPath: agentsDir.path) {
            try fm.createDirectory(at: agentsDir, withIntermediateDirectories: true)
        }
        let linkPath = agentsDir.appendingPathComponent(name)
        if fm.fileExists(atPath: linkPath.path) {
            try fm.removeItem(at: linkPath)
        }
        try fm.createSymbolicLink(atPath: linkPath.path, withDestinationPath: sourceDir.path)
    }

    static func unlinkSkill(named name: String, from projectURL: URL) throws {
        let linkPath = projectURL.appendingPathComponent(".agents/skills/\(name)")
        let fm = FileManager.default
        if fm.fileExists(atPath: linkPath.path) {
            try fm.removeItem(at: linkPath)
        }
    }
}

// MARK: - SourceSkill model

struct SourceSkill: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let displayName: String
    let description: String
    let sourceDirectory: URL
}
