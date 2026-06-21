import Foundation

/// Manages skills via the Claude Code CLI, local filesystem, and GitHub.
final class SkillRepositoryService: @unchecked Sendable {
    static let shared = SkillRepositoryService()
    private let fileManager = FileManager.default

    /// All available marketplace skills (curated + npm MCP registry).
    private let allMarketplaceSkills: [SkillItem] = [
        // Development
        SkillItem(name: "frontend-design", displayName: "Frontend Design", description: "UI/UX 设计模式与前端最佳实践", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "api-builder", displayName: "API Builder", description: "REST 和 GraphQL API 脚手架工具", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "testing-toolkit", displayName: "Testing Toolkit", description: "单元测试、集成测试生成与覆盖率分析", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "code-review", displayName: "Code Review", description: "自动化代码审查、风格检查与最佳实践建议", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "refactoring-assistant", displayName: "Refactoring Assistant", description: "代码重构建议与自动化重写", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "dependency-manager", displayName: "Dependency Manager", description: "依赖分析与版本升级建议", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "git-workflow", displayName: "Git Workflow", description: "Git 工作流优化、commit 规范与 PR 管理", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),

        // Database
        SkillItem(name: "database-ops", displayName: "Database Ops", description: "SQL 迁移、查询优化与数据库管理", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "schema-designer", displayName: "Schema Designer", description: "数据库表结构设计与规范化建议", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),

        // DevOps
        SkillItem(name: "devops-deploy", displayName: "DevOps Deploy", description: "CI/CD 配置、Docker 编排与部署脚本", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "docker-compose", displayName: "Docker Compose", description: "Docker 容器编排与多服务配置", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "k8s-operator", displayName: "K8s Operator", description: "Kubernetes 资源管理与 Helm Chart", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "terraform-planner", displayName: "Terraform Planner", description: "基础设施即代码生成与管理", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),

        // Security
        SkillItem(name: "security-audit", displayName: "Security Audit", description: "代码安全审查、依赖漏洞扫描", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "secret-scanner", displayName: "Secret Scanner", description: "密钥泄露检测与敏感信息扫描", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),

        // Documentation
        SkillItem(name: "docs-generator", displayName: "Docs Generator", description: "API 文档、README 和知识库自动生成", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "changelog-writer", displayName: "Changelog Writer", description: "自动生成 CHANGELOG 与发布说明", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "diagram-generator", displayName: "Diagram Generator", description: "架构图、流程图与 ER 图生成", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),

        // Performance
        SkillItem(name: "performance-tuner", displayName: "Performance Tuner", description: "性能分析与优化建议", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "memory-profiler", displayName: "Memory Profiler", description: "内存分析与泄漏检测", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "bundle-analyzer", displayName: "Bundle Analyzer", description: "构建产物分析与体积优化", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),

        // Language-specific
        SkillItem(name: "python-toolkit", displayName: "Python Toolkit", description: "Python 项目脚手架、类型检查与虚拟环境", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "swift-assistant", displayName: "Swift Assistant", description: "Swift/SwiftUI 开发辅助与最佳实践", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "rust-helper", displayName: "Rust Helper", description: "Rust 项目 cargo 配置与借用检查辅助", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "typescript-utils", displayName: "TypeScript Utils", description: "TypeScript 类型定义生成与重构工具", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "go-toolkit", displayName: "Go Toolkit", description: "Go 项目模块管理与并发模式", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),

        // Data & AI
        SkillItem(name: "data-pipeline", displayName: "Data Pipeline", description: "数据处理流水线设计与 ETL 脚本", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "ml-helper", displayName: "ML Helper", description: "机器学习模型训练与评估辅助", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "prompt-engineer", displayName: "Prompt Engineer", description: "提示词优化与模板管理", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),

        // Misc
        SkillItem(name: "i18n-manager", displayName: "i18n Manager", description: "国际化翻译文件管理与同步", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "migration-tool", displayName: "Migration Tool", description: "框架版本迁移与兼容性修复", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
        SkillItem(name: "regex-builder", displayName: "Regex Builder", description: "正则表达式生成与测试", source: "plugin", version: "", installed: false, enabled: false, isLocal: false, fileCount: 0),
    ]

    // MARK: - Local skills

    func scanLocalSkills() -> [SkillItem] {
        let skillsDir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/skills")

        guard fileManager.fileExists(atPath: skillsDir.path),
              let contents = try? fileManager.contentsOfDirectory(at: skillsDir, includingPropertiesForKeys: nil) else {
            return []
        }

        return contents.compactMap { url in
            guard url.hasDirectoryPath else { return nil }
            let name = url.lastPathComponent
            let files = (try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
            let mdFiles = files.filter { $0.pathExtension == "md" }

            return SkillItem(
                name: name,
                displayName: name.replacingOccurrences(of: "-", with: " ").capitalized,
                description: "本地技能 - \(mdFiles.count) 个文件",
                source: "local",
                installed: true,
                enabled: true,
                isLocal: true,
                fileCount: mdFiles.count
            )
        }
    }

    func enabledPluginSkillIds() -> [String] {
        let settingsURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")

        guard let data = try? Data(contentsOf: settingsURL),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let plugins = dict["enabledPlugins"] as? [String: Any] else {
            return []
        }

        return plugins.keys.map { key in
            if let atIndex = key.firstIndex(of: "@") {
                return String(key[..<atIndex])
            }
            return key
        }
    }

    // MARK: - Marketplace

    func isClaudeCLIAvailable() async -> Bool {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["claude", "--version"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            } catch {
                return false
            }
        }.value
    }

    func fetchMarketplaceSkills() -> [SkillItem] {
        return allMarketplaceSkills
    }

    /// Search marketplace skills by query string — curated list + CLI + npm registry.
    func searchMarketplace(query: String) async -> [SkillItem] {
        // Filter curated marketplace list
        let curatedResults = allMarketplaceSkills.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.displayName.localizedCaseInsensitiveContains(query) ||
            $0.description.localizedCaseInsensitiveContains(query)
        }

        var all = curatedResults

        // Try npm registry for MCP packages
        let npmResults = await fetchFromNPM(query: query)
        for item in npmResults {
            if !all.contains(where: { $0.name == item.name }) {
                all.append(item)
            }
        }

        // Also try CLI search
        if let cliOutput = await runClaudeCLI(["plugins", "search", query]), !cliOutput.isEmpty {
            let cliResults = parsePluginOutput(cliOutput)
            for item in cliResults {
                if !all.contains(where: { $0.name == item.name }) {
                    all.append(item)
                }
            }
        }

        return all
    }

    // MARK: - npm registry

    /// Fetch MCP-related packages from the npm registry.
    private func fetchFromNPM(query: String) async -> [SkillItem] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlStr = "https://registry.npmjs.org/-/v1/search?text=\(encoded)+keywords:mcp-server&size=15"

        guard let url = URL(string: urlStr) else { return [] }

        return await Task.detached {
            var req = URLRequest(url: url)
            req.timeoutInterval = 8

            guard let (data, _) = try? await URLSession.shared.data(for: req),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let objects = json["objects"] as? [[String: Any]] else {
                return []
            }

            return objects.compactMap { obj -> SkillItem? in
                guard let pkg = obj["package"] as? [String: Any],
                      let name = pkg["name"] as? String,
                      let desc = pkg["description"] as? String else { return nil }

                return SkillItem(
                    name: name,
                    displayName: name.replacingOccurrences(of: "-", with: " ").capitalized,
                    description: desc,
                    source: "npm",
                    version: pkg["version"] as? String ?? "",
                    installed: false,
                    enabled: false,
                    isLocal: false,
                    fileCount: 0
                )
            }
        }.value
    }

    // MARK: - GitHub URL detection

    func isGitHubURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("https://github.com/") ||
               trimmed.hasPrefix("github.com/")
    }

    /// Parse owner/repo from GitHub URL. Returns nil on failure.
    func parseGitHubURL(_ url: String) -> (owner: String, repo: String)? {
        var clean = url.trimmingCharacters(in: .whitespaces)
        if !clean.hasPrefix("https://") {
            clean = "https://" + clean
        }

        guard let parsed = URL(string: clean),
              parsed.host?.contains("github.com") == true else { return nil }

        let parts = parsed.path.split(separator: "/")
        guard parts.count >= 2 else { return nil }

        let owner = String(parts[parts.count - 2])
        let repo = String(parts[parts.count - 1])
            .replacingOccurrences(of: ".git", with: "")
        return (owner, repo)
    }

    // MARK: - Install / Uninstall

    func installSkill(_ skill: SkillItem) async -> Bool {
        let result = await runClaudeCLI(["plugins", "install", skill.name])
        return result != nil
    }

    func uninstallSkill(_ skill: SkillItem) async -> Bool {
        let result = await runClaudeCLI(["plugins", "uninstall", skill.name])
        return result != nil
    }

    /// Install a skill by cloning a GitHub repo into ~/.claude/skills/<name>.
    func installFromGitHub(url: String) async -> Bool {
        guard let parsed = parseGitHubURL(url) else { return false }

        let skillsDir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/skills")
        let repoURL = "https://github.com/\(parsed.owner)/\(parsed.repo).git"
        let targetDir = skillsDir.appendingPathComponent(parsed.repo)

        // Already exists?
        if fileManager.fileExists(atPath: targetDir.path) {
            return false
        }

        // Create skills dir if needed
        try? fileManager.createDirectory(at: skillsDir, withIntermediateDirectories: true)

        return await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["git", "clone", "--depth", "1", repoURL, targetDir.path]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            } catch {
                return false
            }
        }.value
    }

    // MARK: - CLI

    private func runClaudeCLI(_ args: [String]) async -> String? {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["claude"] + args
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return nil }
                return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
            } catch {
                return nil
            }
        }.value
    }

    private func parsePluginOutput(_ raw: String) -> [SkillItem] {
        let lines = raw.split(separator: "\n")
        return lines.compactMap { line -> SkillItem? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("!") else { return nil }
            let parts = trimmed.split(separator: " ", maxSplits: 1)
            guard let name = parts.first else { return nil }
            let desc = parts.count > 1 ? String(parts[1]) : "官方插件"
            return SkillItem(
                name: String(name),
                displayName: String(name).replacingOccurrences(of: "-", with: " ").capitalized,
                description: desc,
                source: "plugin",
                version: "",
                installed: false,
                enabled: false,
                isLocal: false,
                fileCount: 0
            )
        }
    }
}
