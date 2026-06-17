# Claude Code Panel

macOS 原生管理面板，用于可视化管理 [Claude Code](https://claude.ai) 的配置。SwiftUI + Liquid Glass 设计语言，中文界面，5 个功能面板。

<p align="center">
  <img src="build/AppIcon_preview.png" width="128" alt="icon">
</p>

## 功能

| 面板 | 功能 |
|------|------|
| **概览** | Claude 版本检测、模型层级状态、配置统计 |
| **API 配置** | 提供商切换、API Key 管理、模型层级设置、连接测试 |
| **配置文件** | `~/.claude.json` / `settings.json` 浏览与编辑 |
| **MCP 服务器** | 服务器 CRUD、连接测试、重命名别名、项目专属分组 |
| **技能管理** | 本地/插件技能浏览、安装、搜索 |

## 平台要求

- macOS 26+ (Lovelace)
- Apple Silicon (arm64)

## 构建

```bash
# 一键构建 + 打包 DMG
bash scripts/build.sh

# 仅编译
swift build -c release --arch arm64 --disable-sandbox
```

构建输出位于 `build/` 目录：`.app` 包 + `.dmg` 安装镜像。

## 项目结构

```
ClaudeCodePanel/
├── Package.swift                     # SPM 清单
├── scripts/
│   ├── build.sh                      # 构建 + 打包脚本
│   └── generate_icon.py              # 图标生成
└── ClaudeCodePanel/
    ├── App/                          # @main 入口
    ├── Models/                       # 数据模型
    │   ├── APIProvider.swift         # 提供商枚举 + ModelTier
    │   ├── MCPServerConfig.swift     # MCP 服务器模型
    │   ├── SkillItem.swift           # 技能模型
    │   ├── ClaudeConfig.swift        # Claude Code 配置
    │   └── DashboardSummary.swift    # 面板摘要
    ├── Services/                     # 服务层（单例）
    │   ├── ConfigFileService.swift   # JSON 配置文件读写
    │   ├── SyncService.swift         # claude.json → 模型同步
    │   ├── MCPService.swift          # MCP 进程管理 + 连接测试
    │   ├── KeychainService.swift     # Keychain API Key 存储
    │   ├── FileWatcherService.swift  # 文件变更监控
    │   └── SkillRepositoryService.swift
    ├── ViewModels/                   # @Observable 视图模型
    └── Views/                        # SwiftUI 视图
        ├── ContentView.swift         # 根布局（HSplitView）
        ├── Sidebar/                  # 侧边导航
        ├── Dashboard/                # 概览面板
        ├── API/                      # API 配置
        ├── Config/                   # 配置文件编辑器
        ├── MCP/                      # MCP 服务器管理
        ├── Skills/                   # 技能管理
        └── Shared/                   # 共享 UI 组件（毛玻璃等）
```

## 架构

```
Views (SwiftUI)
    ↕
ViewModels (@Observable, @MainActor)
    ↕
Services (singleton)
    ↕
~/.claude.json   ~/.claude/settings.json   macOS Keychain
```

- **MVVM**：View → ViewModel → Service
- **配置读写双向**：`SyncService.syncAll()` 从 `~/.claude.json` 加载，`persistServers()` 写回同一文件
- **HSplitView** 手动布局（SPM 可执行文件不支持 `NavigationSplitView`）

## 安装

从 DMG 拖放至 `/Applications`，或直接运行：

```bash
open "build/Claude Code Panel.app"
```

## 许可证

[MIT](LICENSE)
