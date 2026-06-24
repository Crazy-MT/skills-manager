import Foundation

struct ProjectScanner {

    /// Scans a project directory for skill files.
    /// Returns .mdc files from .cursor/rules/ and SKILL.md files up to 3 levels deep.
    func scan(projectURL: URL) -> [Skill] {
        var skills: [Skill] = []

        // .cursor/rules/*.mdc
        let cursorRules = projectURL.appendingPathComponent(".cursor/rules")
        let cursorSkills = scanMDC(in: cursorRules, projectURL: projectURL)
        skills.append(contentsOf: cursorSkills)

        // SKILL.md anywhere in the project (depth ≤ 3)
        let skillMDFiles = findSKILLMD(in: projectURL, depth: 0, maxDepth: 3)
        let claudeSkills = skillMDFiles.compactMap {
            buildSkill(skillFile: $0, projectURL: projectURL, source: .projectLocal(projectURL: projectURL))
        }
        skills.append(contentsOf: claudeSkills)

        return skills
    }

    /// Scans `.agents/skills/` for symlinked skill directories and builds Skill structs
    /// with `.projectLinked` source.
    func scanLinkedSkills(projectURL: URL) -> [Skill] {
        let agentsDir = projectURL.appendingPathComponent(".agents/skills")
        let fm = FileManager.default
        guard fm.fileExists(atPath: agentsDir.path) else { return [] }
        guard let entries = try? fm.contentsOfDirectory(
            at: agentsDir,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return entries.compactMap { entry -> Skill? in
            // Resolve symlink to find the real SKILL.md
            guard let dest = try? fm.destinationOfSymbolicLink(atPath: entry.path) else { return nil }
            let resolvedDir: URL
            if dest.hasPrefix("/") {
                resolvedDir = URL(fileURLWithPath: dest)
            } else {
                resolvedDir = entry.deletingLastPathComponent().appendingPathComponent(dest)
            }

            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: resolvedDir.path, isDirectory: &isDir), isDir.boolValue else { return nil }

            let skillFile = resolvedDir.appendingPathComponent("SKILL.md")
            guard fm.fileExists(atPath: skillFile.path) else { return nil }

            return buildLinkedSkill(skillFile: skillFile, skillName: entry.lastPathComponent, resolvedDir: resolvedDir, projectURL: projectURL)
        }
    }

    private func buildLinkedSkill(skillFile: URL, skillName: String, resolvedDir: URL, projectURL: URL) -> Skill? {
        guard let content = try? String(contentsOf: skillFile, encoding: .utf8) else { return nil }
        let parsed = SkillParser.parse(content: content)
        let fm = parsed.frontmatter

        let displayName = fm["name"] ?? skillName
        let description = fm["description"] ?? ""
        let rawTags = fm["tags"] ?? fm["keywords"] ?? ""
        let tags = rawTags
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let agents = fm["compatible_agents"]
            .map { $0.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
            ?? ["Claude Code"]

        return Skill(
            id: "project-linked:\(projectURL.lastPathComponent):\(skillName)",
            name: skillName,
            displayName: displayName,
            baseDescription: description,
            baseDescriptionLocale: DescriptionLocale.descriptionLocale(frontmatter: fm, description: description),
            localizedDescription: nil,
            source: .projectLinked(projectURL: projectURL),
            version: fm["version"],
            filePath: skillFile,
            directoryPath: resolvedDir,
            compatibleAgents: agents,
            tags: tags,
            markdownContent: content,
            frontmatter: fm
        )
    }

    // MARK: - Private

    /// Scans a directory for *.mdc files, building Skill structs with .projectLocal source.
    private func scanMDC(in directory: URL, projectURL: URL) -> [Skill] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else { return [] }
        guard let entries = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return entries.compactMap { url -> Skill? in
            guard url.pathExtension == "mdc" else { return nil }
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let filename = url.deletingPathExtension().lastPathComponent
            let parsed = SkillFormatConverter.parseMDC(content: content)
            let description = parsed.frontmatter["description"] ?? ""
            let rawGlobs = parsed.frontmatter["globs"] ?? "[]"
            let tags = SkillFormatConverter.parseGlobs(rawGlobs)
            return Skill(
                id: "project:\(projectURL.lastPathComponent):\(filename)",
                name: filename,
                displayName: filename,
                baseDescription: description,
                baseDescriptionLocale: DescriptionLocale.descriptionLocale(frontmatter: parsed.frontmatter, description: description),
                localizedDescription: nil,
                source: .projectLocal(projectURL: projectURL),
                version: nil,
                filePath: url,
                directoryPath: url.deletingLastPathComponent(),
                compatibleAgents: ["Cursor"],
                tags: tags,
                markdownContent: content,
                frontmatter: parsed.frontmatter
            )
        }
    }

    private func findSKILLMD(in directory: URL, depth: Int, maxDepth: Int) -> [URL] {
        guard depth <= maxDepth else { return [] }
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [URL] = []
        for entry in entries {
            var isDir: ObjCBool = false
            fm.fileExists(atPath: entry.path, isDirectory: &isDir)
            if isDir.boolValue {
                results.append(contentsOf: findSKILLMD(in: entry, depth: depth + 1, maxDepth: maxDepth))
            } else if entry.lastPathComponent == "SKILL.md" {
                results.append(entry)
            }
        }
        return results
    }

    private func buildSkill(skillFile: URL, projectURL: URL, source: SkillSource) -> Skill? {
        guard let content = try? String(contentsOf: skillFile, encoding: .utf8) else { return nil }
        let parsed = SkillParser.parse(content: content)
        let fm = parsed.frontmatter

        let skillDirPath = skillFile.deletingLastPathComponent().standardized.path
        let projectPath = projectURL.standardized.path
        let dirName: String
        if skillDirPath == projectPath {
            dirName = "root"
        } else if skillDirPath.hasPrefix(projectPath + "/") {
            dirName = String(skillDirPath.dropFirst(projectPath.count + 1))
        } else {
            dirName = skillFile.deletingLastPathComponent().lastPathComponent
        }
        let displayName = fm["name"] ?? dirName
        let description = fm["description"] ?? ""
        let rawTags = fm["tags"] ?? fm["keywords"] ?? ""
        let tags = rawTags
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let agents = fm["compatible_agents"]
            .map { $0.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
            ?? ["Claude Code"]

        return Skill(
            id: "project:\(projectURL.lastPathComponent):\(dirName)",
            name: dirName,
            displayName: displayName,
            baseDescription: description,
            baseDescriptionLocale: DescriptionLocale.descriptionLocale(frontmatter: fm, description: description),
            localizedDescription: nil,
            source: source,
            version: fm["version"],
            filePath: skillFile,
            directoryPath: skillFile.deletingLastPathComponent(),
            compatibleAgents: agents,
            tags: tags,
            markdownContent: content,
            frontmatter: fm
        )
    }
}
