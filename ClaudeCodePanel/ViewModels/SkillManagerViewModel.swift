import Foundation
import Observation

@MainActor
@Observable
final class SkillManagerViewModel {
    var installedSkills: [SkillItem] = []
    var marketplaceSkills: [SkillItem] = []
    var isLoading: Bool = false
    var searchQuery: String = ""
    var errorMessage: String?

    private let skillRepo = SkillRepositoryService.shared

    var filteredInstalledSkills: [SkillItem] {
        if searchQuery.isEmpty { return installedSkills }
        return installedSkills.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery) ||
            $0.displayName.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var filteredMarketplaceSkills: [SkillItem] {
        if searchQuery.isEmpty { return marketplaceSkills }
        return marketplaceSkills.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery) ||
            $0.displayName.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    func loadSkills() {
        isLoading = true

        // Load local skills
        installedSkills = skillRepo.scanLocalSkills()

        // Load plugin-based skills
        let pluginIds = skillRepo.enabledPluginSkillIds()
        for pluginId in pluginIds {
            if !installedSkills.contains(where: { $0.name == pluginId }) {
                let skill = SkillItem(
                    name: pluginId,
                    displayName: pluginId.replacingOccurrences(of: "-", with: " ").capitalized,
                    description: "插件 · 已启用",
                    source: "plugin",
                    installed: true,
                    enabled: true,
                    isLocal: false,
                    fileCount: 0
                )
                installedSkills.append(skill)
            }
        }

        // Marketplace (simulated — would come from plugin registry)
        marketplaceSkills = [
            SkillItem(name: "frontend-design", displayName: "Frontend Design", description: "UI/UX design and frontend patterns", source: "marketplace", version: "1.0.0", installed: false, isLocal: false),
            SkillItem(name: "api-builder", displayName: "API Builder", description: "REST and GraphQL API scaffolding", source: "marketplace", version: "1.2.0", installed: false, isLocal: false),
            SkillItem(name: "database-ops", displayName: "Database Ops", description: "SQL migration and optimization tools", source: "marketplace", version: "0.9.0", installed: false, isLocal: false),
        ]

        isLoading = false
    }

    func installMarketplaceSkill(_ skill: SkillItem) {
        let updated = skill
        updated.installed = true
        updated.enabled = true
        if !installedSkills.contains(where: { $0.name == skill.name }) {
            installedSkills.append(updated)
        }
    }

    func removeSkill(_ skill: SkillItem) {
        installedSkills.removeAll { $0.id == skill.id }
    }
}
