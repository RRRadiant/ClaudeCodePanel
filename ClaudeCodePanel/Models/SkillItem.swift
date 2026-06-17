import Foundation

@Observable
final class SkillItem: Identifiable, Equatable, @unchecked Sendable {
    let id: UUID
    var name: String
    var displayName: String
    var description: String
    var source: String
    var version: String
    var installed: Bool
    var enabled: Bool
    var isLocal: Bool
    var fileCount: Int

    init(
        id: UUID = UUID(),
        name: String = "",
        displayName: String = "",
        description: String = "",
        source: String = "",
        version: String = "",
        installed: Bool = false,
        enabled: Bool = true,
        isLocal: Bool = false,
        fileCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.description = description
        self.source = source
        self.version = version
        self.installed = installed
        self.enabled = enabled
        self.isLocal = isLocal
        self.fileCount = fileCount
    }

    static func == (lhs: SkillItem, rhs: SkillItem) -> Bool {
        lhs.id == rhs.id
    }
}
