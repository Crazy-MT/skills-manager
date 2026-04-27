import Foundation

actor DiscoverDirectoryCache {
    struct Snapshot: Sendable {
        var skills: [DiscoverSkill]
        var total: Int
        var updatedAt: Date?
    }

    private struct CacheFile: Codable {
        var version: Int
        var updatedAt: Date
        var index: [String: Entry]
        var details: [String: Detail]
        var categories: [String: StoredSnapshot]
        var searches: [String: StoredSnapshot]
    }

    private struct StoredSnapshot: Codable {
        var skillIDs: [String]
        var total: Int
        var updatedAt: Date
    }

    private struct Entry: Codable {
        var id: String
        var source: String
        var skillId: String
        var name: String
        var installs: Int
        var lastSeenAt: Date
    }

    private struct Detail: Codable {
        var id: String
        var installCommand: String
        var baseDescription: String?
        var baseDescriptionLocale: String
        var readmeExcerpt: String?
        var fetchedAt: Date
    }

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var cachedFile: CacheFile?

    init(fileURL: URL? = nil) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.fileURL = fileURL ?? home
            .appendingPathComponent(".skills-manager/cache/discover-directory.json")
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func directorySnapshot(category: DiscoverDirectoryCategory) -> Snapshot? {
        let file = loadCacheFile()
        guard let snapshot = file.categories[category.rawValue] else { return nil }
        return buildSnapshot(snapshot, from: file)
    }

    func searchSnapshot(query: String) -> Snapshot? {
        let file = loadCacheFile()
        guard let snapshot = file.searches[Self.searchKey(query)] else { return nil }
        return buildSnapshot(snapshot, from: file)
    }

    func detail(for skillID: String) -> DiscoverSkill? {
        let file = loadCacheFile()
        return buildSkill(id: skillID, from: file)
    }

    func isDetailStale(for skillID: String, olderThan interval: TimeInterval) -> Bool {
        let file = loadCacheFile()
        guard let fetchedAt = file.details[skillID]?.fetchedAt else { return true }
        return Date().timeIntervalSince(fetchedAt) > interval
    }

    func allDetails() -> [DiscoverSkill] {
        let file = loadCacheFile()
        return file.details.keys.sorted().compactMap { buildSkill(id: $0, from: file) }
    }

    func storeDirectory(skills: [DiscoverSkill], total: Int, category: DiscoverDirectoryCategory) {
        var file = loadCacheFile()
        let now = Date()
        upsert(skills, in: &file, now: now)
        file.categories[category.rawValue] = StoredSnapshot(
            skillIDs: skills.map(\.id),
            total: total,
            updatedAt: now
        )
        file.updatedAt = now
        cachedFile = file
        persist(file)
    }

    func storeSearch(query: String, skills: [DiscoverSkill], count: Int) {
        var file = loadCacheFile()
        let now = Date()
        upsert(skills, in: &file, now: now)
        file.searches[Self.searchKey(query)] = StoredSnapshot(
            skillIDs: skills.map(\.id),
            total: count,
            updatedAt: now
        )
        file.updatedAt = now
        cachedFile = file
        persist(file)
    }

    func storeDetail(_ skill: DiscoverSkill) {
        var file = loadCacheFile()
        let now = Date()
        upsert([skill], in: &file, now: now)
        file.details[skill.id] = Detail(
            id: skill.id,
            installCommand: skill.installCommand,
            baseDescription: skill.baseDescription,
            baseDescriptionLocale: skill.baseDescriptionLocale,
            readmeExcerpt: skill.readmeExcerpt,
            fetchedAt: now
        )
        file.updatedAt = now
        cachedFile = file
        persist(file)
    }

    private func buildSnapshot(_ snapshot: StoredSnapshot, from file: CacheFile) -> Snapshot {
        Snapshot(
            skills: snapshot.skillIDs.compactMap { buildSkill(id: $0, from: file) },
            total: snapshot.total,
            updatedAt: snapshot.updatedAt
        )
    }

    private func buildSkill(id: String, from file: CacheFile) -> DiscoverSkill? {
        guard let entry = file.index[id],
              let repoURL = URL(string: "https://github.com/\(entry.source)")
        else {
            return nil
        }

        let detail = file.details[id]
        return DiscoverSkill(
            id: entry.id,
            source: entry.source,
            skillId: entry.skillId,
            name: entry.name,
            installs: entry.installs,
            repoURL: repoURL,
            installCommand: detail?.installCommand ?? "npx skills add https://github.com/\(entry.source) --skill \(entry.skillId)",
            baseDescription: detail?.baseDescription,
            baseDescriptionLocale: detail?.baseDescriptionLocale ?? "en",
            localizedDescription: nil,
            readmeExcerpt: detail?.readmeExcerpt
        )
    }

    private func upsert(_ skills: [DiscoverSkill], in file: inout CacheFile, now: Date) {
        for skill in skills {
            file.index[skill.id] = Entry(
                id: skill.id,
                source: skill.source,
                skillId: skill.skillId,
                name: skill.name,
                installs: skill.installs,
                lastSeenAt: now
            )

            if skill.baseDescription != nil || skill.readmeExcerpt != nil {
                file.details[skill.id] = Detail(
                    id: skill.id,
                    installCommand: skill.installCommand,
                    baseDescription: skill.baseDescription,
                    baseDescriptionLocale: skill.baseDescriptionLocale,
                    readmeExcerpt: skill.readmeExcerpt,
                    fetchedAt: file.details[skill.id]?.fetchedAt ?? now
                )
            }
        }
    }

    private func loadCacheFile() -> CacheFile {
        if let cachedFile {
            return cachedFile
        }
        guard
            let data = try? Data(contentsOf: fileURL),
            let decoded = try? decoder.decode(CacheFile.self, from: data),
            decoded.version == 1
        else {
            let empty = CacheFile(
                version: 1,
                updatedAt: Date.distantPast,
                index: [:],
                details: [:],
                categories: [:],
                searches: [:]
            )
            cachedFile = empty
            return empty
        }
        cachedFile = decoded
        return decoded
    }

    private func persist(_ file: CacheFile) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            let data = try encoder.encode(file)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Discover can always refetch from skills.sh; cache writes are best effort.
        }
    }

    private static func searchKey(_ query: String) -> String {
        query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
