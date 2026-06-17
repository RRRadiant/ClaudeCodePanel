import Foundation
import Observation

@MainActor
@Observable
final class SkillManagerViewModel {
    var installedSkills: [SkillItem] = []
    var marketplaceSkills: [SkillItem] = []
    var searchResults: [SkillItem] = []
    var isLoading: Bool = false
    var isInstalling: Bool = false
    var marketplaceAvailable: Bool = false
    var searchQuery: String = ""
    var githubURL: String = ""
    var errorMessage: String?
    var successMessage: String?

    private let skillRepo = SkillRepositoryService.shared

    var isGitHubMode: Bool {
        skillRepo.isGitHubURL(searchQuery)
    }

    var parsedGitHubRepo: String? {
        guard let parsed = skillRepo.parseGitHubURL(searchQuery) else { return nil }
        return "\(parsed.owner)/\(parsed.repo)"
    }

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

    func loadSkills() async {
        isLoading = true
        errorMessage = nil

        installedSkills = skillRepo.scanLocalSkills()

        let pluginIds = skillRepo.enabledPluginSkillIds()
        for pluginId in pluginIds {
            if !installedSkills.contains(where: { $0.name == pluginId }) {
                let skill = SkillItem(
                    name: pluginId,
                    displayName: pluginId.replacingOccurrences(of: "-", with: " ").capitalized,
                    description: "插件 - 已启用",
                    source: "plugin",
                    installed: true,
                    enabled: true,
                    isLocal: false,
                    fileCount: 0
                )
                installedSkills.append(skill)
            }
        }

        marketplaceAvailable = skillRepo.isClaudeCLIAvailable()
        marketplaceSkills = skillRepo.fetchMarketplaceSkills()
        let installedNames = Set(installedSkills.map(\.name))
        marketplaceSkills.removeAll { installedNames.contains($0.name) }

        isLoading = false
    }

    // MARK: - Search

    func performSearch() async {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isLoading = true
        errorMessage = nil

        // GitHub URL mode — handled separately via installFromGitHub
        if skillRepo.isGitHubURL(query) {
            searchResults = []
            isLoading = false
            return
        }

        // Marketplace search
        searchResults = await skillRepo.searchMarketplace(query: query)
        // Remove already installed
        let installedNames = Set(installedSkills.map(\.name))
        searchResults.removeAll { installedNames.contains($0.name) }

        isLoading = false
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
    }

    // MARK: - Install from Marketplace

    func installMarketplaceSkill(_ skill: SkillItem) async {
        isInstalling = true
        errorMessage = nil
        successMessage = nil

        let success = await skillRepo.installSkill(skill)
        if success {
            let updated = skill
            updated.installed = true
            updated.enabled = true
            installedSkills.append(updated)
            marketplaceSkills.removeAll { $0.name == skill.name }
            searchResults.removeAll { $0.name == skill.name }
            successMessage = "已安装 \(skill.displayName)"
        } else {
            errorMessage = "安装失败 - Claude CLI 未安装或插件不可用"
        }

        isInstalling = false
    }

    // MARK: - Install from GitHub

    func installFromGitHub() async {
        let url = searchQuery.trimmingCharacters(in: .whitespaces)
        guard skillRepo.isGitHubURL(url), let parsed = skillRepo.parseGitHubURL(url) else {
            errorMessage = "无效的 GitHub 链接"
            return
        }

        isInstalling = true
        errorMessage = nil
        successMessage = nil

        let success = await skillRepo.installFromGitHub(url: url)
        if success {
            successMessage = "已从 GitHub 安装: \(parsed.repo)"
            // Reload local skills to show the new one
            installedSkills = skillRepo.scanLocalSkills()
            searchQuery = ""
            githubURL = ""
        } else {
            errorMessage = "安装失败 - 请检查链接是否正确或仓库是否已存在"
        }

        isInstalling = false
    }

    // MARK: - Remove

    func removeSkill(_ skill: SkillItem) {
        installedSkills.removeAll { $0.id == skill.id }

        if skill.source == "plugin" {
            Task { await skillRepo.uninstallSkill(skill) }
        }
    }
}
