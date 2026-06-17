import SwiftUI

struct SkillsListView: View {
    @State private var viewModel = SkillManagerViewModel()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("技能管理")
                            .font(.title)
                            .fontWeight(.semibold)
                        Text("\(viewModel.installedSkills.count) 个已安装 · \(viewModel.marketplaceSkills.count) 个可用")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                // Search + GitHub input
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.isGitHubMode ? "link" : "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField(
                            viewModel.isGitHubMode ? "粘贴 GitHub 仓库链接..." : "搜索技能或粘贴 GitHub 链接...",
                            text: $viewModel.searchQuery
                        )
                        .textFieldStyle(.plain)
                        .focused($isSearchFocused)
                        .onSubmit { Task { await handleSubmit() } }
                        .padding(10)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 7))

                        if !viewModel.searchQuery.isEmpty {
                            Button(action: { viewModel.clearSearch() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // GitHub mode action bar
                    if viewModel.isGitHubMode, let repo = viewModel.parsedGitHubRepo {
                        HStack(spacing: 10) {
                            Image(systemName: "shippingbox")
                                .foregroundStyle(.blue)
                            Text("从 GitHub 安装:")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text(repo)
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Spacer()
                            GlassButton(
                                title: viewModel.isInstalling ? "安装中..." : "安装",
                                systemImage: "arrow.down.circle",
                                variant: .primary,
                                size: .small,
                                action: { Task { await viewModel.installFromGitHub() } }
                            )
                            .disabled(viewModel.isInstalling)
                        }
                        .padding(12)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                // Messages
                if let msg = viewModel.successMessage {
                    Text(msg).font(.caption).foregroundStyle(.green)
                }
                if let msg = viewModel.errorMessage {
                    Text(msg).font(.caption).foregroundStyle(.red)
                }

                // Search results
                if !viewModel.searchResults.isEmpty {
                    sectionHeader("搜索结果")

                    ForEach(viewModel.searchResults) { skill in
                        SkillCard(
                            skill: skill,
                            actionTitle: "安装",
                            actionRole: nil,
                            onAction: { Task { await viewModel.installMarketplaceSkill(skill) } }
                        )
                    }
                }

                // Installed Skills
                if !viewModel.filteredInstalledSkills.isEmpty {
                    sectionHeader("已安装")

                    ForEach(viewModel.filteredInstalledSkills) { skill in
                        SkillCard(
                            skill: skill,
                            actionTitle: "移除",
                            actionRole: .destructive,
                            onAction: { viewModel.removeSkill(skill) }
                        )
                    }
                }

                // Marketplace
                if !viewModel.filteredMarketplaceSkills.isEmpty && viewModel.searchQuery.isEmpty {
                    sectionHeader("市场")

                    ForEach(viewModel.filteredMarketplaceSkills) { skill in
                        SkillCard(
                            skill: skill,
                            actionTitle: "安装",
                            actionRole: nil,
                            onAction: { Task { await viewModel.installMarketplaceSkill(skill) } }
                        )
                    }
                }

                // Marketplace unavailable hint
                if !viewModel.isLoading && !viewModel.marketplaceAvailable && viewModel.searchQuery.isEmpty {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("安装 Claude CLI 后可通过市场一键安装技能")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                if !viewModel.isLoading &&
                   viewModel.filteredInstalledSkills.isEmpty &&
                   viewModel.filteredMarketplaceSkills.isEmpty &&
                   viewModel.searchResults.isEmpty &&
                   viewModel.searchQuery.isEmpty {
                    EmptyState(icon: "puzzlepiece.extension", message: "未找到技能")
                }

                if !viewModel.isLoading &&
                   viewModel.filteredInstalledSkills.isEmpty &&
                   viewModel.filteredMarketplaceSkills.isEmpty &&
                   viewModel.searchResults.isEmpty &&
                   !viewModel.searchQuery.isEmpty &&
                   !viewModel.isGitHubMode {
                    EmptyState(icon: "magnifyingglass", message: "未找到匹配的技能")
                }
            }
            .padding(32)
            .frame(maxWidth: 720)
        }
        .task { await viewModel.loadSkills() }
    }

    // MARK: - Submit handler

    private func handleSubmit() async {
        if viewModel.isGitHubMode {
            await viewModel.installFromGitHub()
        } else if !viewModel.searchQuery.isEmpty {
            await viewModel.performSearch()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 8)
    }
}
