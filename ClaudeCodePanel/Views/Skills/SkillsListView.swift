import SwiftUI

struct SkillsListView: View {
    @State private var viewModel = SkillManagerViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
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

                SearchField(placeholder: "搜索技能...", text: $viewModel.searchQuery)

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

                // Marketplace Skills
                if !viewModel.filteredMarketplaceSkills.isEmpty {
                    sectionHeader("市场")

                    ForEach(viewModel.filteredMarketplaceSkills) { skill in
                        SkillCard(
                            skill: skill,
                            actionTitle: "安装",
                            actionRole: nil,
                            onAction: { viewModel.installMarketplaceSkill(skill) }
                        )
                    }
                }

                if viewModel.filteredInstalledSkills.isEmpty && viewModel.filteredMarketplaceSkills.isEmpty {
                    EmptyState(icon: "puzzlepiece.extension", message: "未找到技能")
                }
            }
            .padding(32)
            .frame(maxWidth: 720)
        }
        .task { viewModel.loadSkills() }
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
