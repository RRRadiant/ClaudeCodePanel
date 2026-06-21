# Claude Code Panel — Handoff

## 概览

一个 macOS 原生管理面板，用于可视化管理 Claude Code 的配置。SwiftUI + Liquid Glass 2.0（macOS 26 Lovelace），中文界面，5 个功能面板。

| | |
|---|---|
| **目标平台** | macOS 26+ (Lovelace)，Apple Silicon |
| **构建系统** | Swift Package Manager（`swift build`） |
| **语言** | Swift 6，`@Observable` 宏 |
| **UI 框架** | SwiftUI（HSplitView 布局） |
| **当前版本** | 1.9 |
| **安装方式** | DMG → `/Applications` 拖放 |

## 项目结构

```
ClaudeCodePanel/
├── Package.swift                        # SPM 清单（macOS 26 可执行文件目标）
├── HANDOFF.md                           # 本文件
├── scripts/
│   ├── build.sh                         # 一站式构建+打包脚本（含 DMG 背景+布局）
│   ├── generate_icon.py                 # Python 图标生成（Pillow→iconutil）+ DMG 背景图
│   └── notarize.sh                      # Apple 公证脚本（API Key / Apple ID）
├── ClaudeCodePanel/
│   ├── App/
│   │   ├── ClaudeCodePanelApp.swift     # @main 入口，NSApplication 设置
│   │   └── AppDelegate.swift            # NSApp delegate
│   ├── Models/
│   │   ├── APIProvider.swift            # 提供商枚举 + ModelTier 层级映射
│   │   ├── MCPServerConfig.swift        # MCP 服务器配置模型（核心）
│   │   ├── SkillItem.swift              # 技能模型
│   │   └── ReleaseInfo.swift            # 更新发布信息模型
│   ├── Services/
│   │   ├── ConfigFileService.swift      # 配置文件读写（JSON 原子写入）
│   │   ├── FileWatcherService.swift     # 文件变更监控
│   │   ├── KeychainService.swift        # Keychain API Key 存储
│   │   ├── MCPService.swift             # MCP 进程管理+连接测试
│   │   ├── SkillRepositoryService.swift # 技能市场仓库
│   │   └── SyncService.swift            # claude.json→模型 同步（核心）
│   ├── ViewModels/
│   │   ├── APIConfigViewModel.swift      # API 配置面板逻辑
│   │   ├── ConfigEditorViewModel.swift   # 配置文件编辑器逻辑
│   │   ├── DashboardViewModel.swift      # 概览面板逻辑
│   │   ├── MCPManagerViewModel.swift     # MCP 面板逻辑（CRUD+重命名+同步）
│   │   └── SkillManagerViewModel.swift   # 技能管理逻辑
│   └── Views/
│       ├── ContentView.swift             # 根视图（HSplitView 布局）
│       ├── Sidebar/
│       │   ├── SidebarView.swift         # 侧边导航（5 面板）
│       │   └── SidebarItem.swift         # 单个导航项
│       ├── Dashboard/
│       │   └── DashboardView.swift       # 概览面板（状态栏+模型层级+统计）
│       ├── API/
│       │   ├── APIConfigView.swift       # API 配置面板
│       │   └── APIKeyInputView.swift     # API Key 输入组件
│       ├── Config/
│       │   ├── ConfigEditorView.swift    # 配置文件编辑器（主视图）
│       │   ├── ConfigFileList.swift      # 文件列表
│       │   ├── ConfigCodeEditor.swift    # 代码编辑器
│       ├── MCP/
│       │   ├── MCPServerListView.swift   # MCP 服务器列表+分组
│       │   ├── MCPServerCard.swift       # 单个 MCP 服务器卡片
│       │   └── MCPServerEditorView.swift # 服务器编辑表单
│       ├── Skills/
│       │   ├── SkillsListView.swift      # 技能列表
│       │   ├── SkillCard.swift           # 单个技能卡片
│       │   └── SkillInstallSheet.swift   # 安装技能弹窗
│       └── Shared/
│           ├── LiquidGlassModifiers.swift # 毛玻璃 Effect + 视觉修饰符
│           ├── GlassCard.swift            # 玻璃卡片容器
│           ├── GlassButton.swift          # 玻璃按钮
│           ├── GlassTextField.swift       # 玻璃文本框
│           ├── StatusIndicator.swift      # 状态指示灯
│           ├── Badge.swift                # 标签/徽章
│           ├── AsyncButton.swift          # 异步加载按钮
│           ├── SearchField.swift          # 搜索框
│           └── UtilityViews.swift         # 通用视图（EmptyState 等）
│           ├── SyntaxHighlighter.swift       # JSON/TOML/YAML 语法高亮引擎
│           └── HighlightedTextEditor.swift   # NSViewRepresentable 高亮编辑器
├── Tests/
│   ├── MCPServerConfigTests.swift        # MCPServerConfig 解析/序列化/显示测试
│   ├── APIProviderTests.swift            # APIProvider + ModelTier 测试
│   └── SyntaxHighlighterTests.swift      # 语法高亮 token 着色测试
```

## 架构

```
┌──────────────────────────────────────────────────────┐
│  Views (SwiftUI)                                     │
│  ContentView → SidebarView + 5 Panel Views           │
│  Shared components: GlassCard, Badge, StatusIndicator│
├──────────────────────────────────────────────────────┤
│  ViewModels (@Observable, @MainActor)                │
│  每个面板一个 VM，持有 @State 状态                    │
├──────────────────────────────────────────────────────┤
│  Services (singleton, @unchecked Sendable)            │
│  SyncService: claude.json → 模型                     │
│  MCPService:  进程生命周期 + 连接测试                 │
│  ConfigFileService: JSON 读写（原子 temp→move）       │
├──────────────────────────────────────────────────────┤
│  Models (@Observable, Codable, Identifiable)          │
│  MCPServerConfig, APIProvider, SkillItem, etc.       │
└──────────────────────────────────────────────────────┘
```

### 模式

- **MVVM**：View → ViewModel（`@Observable`）→ Service（单例）
- **SPM 可执行文件**：非 Xcode 项目 —— `swift build` 即构建
- **HSplitView**：`NavigationSplitView` 在 SPM 中不可用，故使用 `HSplitView` 手动布局
- **`NSApplication.shared.setActivationPolicy(.regular)`**：SPM 窗口需要显式设置
- **NO `.glassBackgroundEffect` on WindowGroup**：会破坏 SPM 窗口

## 关键设计决策

### 1. 配置文件数据流

```
~/.claude.json  ←── 读写 ──→  应用
     │
     ├─ mcpServers (顶层)  → 全局 MCP 服务器定义
     ├─ projects.<path>.mcpServers → 项目级引用（仅名字数组）
     ├─ projects.<path>.enabledMcpjsonServers → 启用的 JSON/builtin MCP
     └─ projects.<path>.disabledMcpServers → 禁用的 MCP
```

**读写双向**：`SyncService.syncAll()` 从 `~/.claude.json` 加载，`MCPManagerViewModel.persistServers()` 写回同一个文件。

### 2. MCP 去重键

使用 `(name, sourceProject)` 组合键，而非仅 `name`。这允许同名服务器在不同项目中独立存在。（v1.5 修复）

### 3. 重命名机制

显示别名存储在 `~/.claude/mcp-display-names.json`（独立文件）。**绝不修改 `claude.json` 中的原始名称。** 别名仅 UI 显示时生效。

### 4. API 模型层级

`ModelTier` 枚举（opus/sonnet/haiku）映射到 settings.json 环境变量：

| 层级 | 环境变量 |
|------|----------|
| Opus | `ANTHROPIC_DEFAULT_OPUS_MODEL` |
| Sonnet | `ANTHROPIC_DEFAULT_SONNET_MODEL` |
| Haiku | `ANTHROPIC_DEFAULT_HAIKU_MODEL` |

### 5. MCP 服务器类型

| 类型 | JSON 格式 | 用途 |
|------|-----------|------|
| `stdio` | `{"type":"stdio","command":"...","args":[...]}` | 子进程 MCP 服务器 |
| `sse` | `{"type":"sse","url":"http://..."}` | HTTP SSE 端点 |
| `builtin` | 在 `enabledMcpjsonServers` 中列出 | Claude Code 内置（如 `computer-use`） |
| `plugin` | `"plugin:xxx:mcp-search"` 格式 | 社区插件 |

## 每个文件做什么

### Models

| 文件 | 关键类型/方法 | 说明 |
|------|-------------|------|
| `APIProvider.swift` | `ModelTier`, `APIProvider` 枚举 | 模型层级→环境变量映射；`knownModels` 提供自动补全 |
| `MCPServerConfig.swift` | `MCPServerConfig`, `fromJSON()`, `toClaudeJSONEntry()` | MCP 服务器核心模型。`fromJSON` 解析 claude.json 条目；`toClaudeJSONEntry` 生成不含 `name` 的值字典 |
| `SkillItem.swift` | `SkillItem` | 技能元数据 |
| `ClaudeConfig.swift` | `ClaudeConfig` | Claude Code 顶级配置 |
| `DashboardSummary.swift` | `DashboardSummary` | 概览面板聚合数据 |

### Services

| 文件 | 关键方法 | 说明 |
|------|---------|------|
| `ConfigFileService.swift` | `readJSON(at:)`, `writeJSON(_:to:)` | 原子写（先写 .tmp → move），`claudeGlobalConfigPath` 指向 `~/.claude.json` |
| `SyncService.swift` | `syncAll() → SyncedConfig` | 解析 `~/.claude.json`（全局+所有项目），`settings.json` env vars，插件列表 |
| `MCPService.swift` | `startServer()`, `stopServer()`, `testSSE()`, `testSTDIO()` | 进程管理（Process）+ 连接测试 |
| `KeychainService.swift` | `save/load/delete` | macOS Keychain 存储 API Key |
| `FileWatcherService.swift` | | 监控配置目录变更 |
| `SkillRepositoryService.swift` | | 技能市场仓库管理 |

### ViewModels

| 文件 | 关键功能 |
|------|---------|
| `MCPManagerViewModel.swift` | `syncNow()` 从 claude.json 同步；`testServer()` 测试连接；`persistServers()` 写回 claude.json；重命名（别名不修改原始配置）；CRUD |
| `APIConfigViewModel.swift` | 模型层级选择，API Key 管理，连接测试，Provider/BaseURL 配置 |
| `DashboardViewModel.swift` | Claude CLI 检测，配置统计，模型层级信息 |
| `ConfigEditorViewModel.swift` | 配置文件编辑器逻辑 |
| `SkillManagerViewModel.swift` | 技能安装/卸载/启用 |

### Views

| 文件 | 说明 |
|------|------|
| `ContentView.swift` | 根视图 —— `HSplitView` 分割侧边栏(180px) + 内容区域 |
| `SidebarView.swift` | 5 个中文面板导航项 |
| `DashboardView.swift` | 状态栏（Claude 版本/提供商/当前模型）+ 模型层级网格 + 统计卡片 |
| `APIConfigView.swift` | 5 张卡片：提供商、认证、模型层级、当前模型、模型检测 |
| `ConfigEditorView.swift` | 配置文件浏览/编辑 |
| `MCPServerListView.swift` | "全局"+"项目专属" 两组服务器列表，同步按钮，添加按钮 |
| `MCPServerCard.swift` | 单张服务器卡片（展开/折叠），悬停显示重命名/菜单 |
| `MCPServerEditorView.swift` | 服务器编辑表单（命令/参数/环境变量） |
| `SkillsListView.swift` | 技能浏览和管理 |

### Shared（共享 UI 组件）

| 文件 | 说明 |
|------|------|
| `LiquidGlassModifiers.swift` | `IndicatorStatus` 枚举，`GlassMaterial`，毛玻璃修饰符 |
| `GlassCard.swift` | 玻璃卡片容器（`.regularMaterial` 背景+圆角） |
| `GlassButton.swift` | `primary`/`secondary`/`destructive` 三种变体 |
| `Badge.swift` | `info`/`success`/`warning`/`error`/`neutral` 标签 |
| `StatusIndicator.swift` | 红/黄/绿 圆点指示灯 |
| `EmptyState` (UtilityViews) | 空白页提示 |

## 构建和打包

```bash
# 一键构建+打包 DMG
bash scripts/build.sh
```

脚本执行顺序：
1. **生成图标** → `python3 scripts/generate_icon.py` → `iconutil -c icns`
2. **Swift 构建** → `swift build -c release --arch arm64` → strip 二进制
3. **创建 .app 包** → 手动构造 `Contents/{MacOS,Resources,Info.plist,PkgInfo}`
4. **代码签名** → `codesign --sign - --force --deep`（ad-hoc）
5. **验证包** → `lipo -info`，文件列表
6. **创建 DMG** → `hdiutil create` → attach → 复制 app + Applications 快捷方式 → `hdiutil convert -format UDZO`

### DMG 布局

挂载后可见两个图标：
- `/Claude Code Panel.app`
- `/Applications`（快捷方式）

## 注意事项

### 不需要做的事
- 不要修改 `~/.claude.json` 的非 MCP 键（`persistServers` 只触碰 `mcpServers`/`projects` 中的 MCP 相关部分）
- 不要在 `toClaudeJSONEntry()` 中包含 `name` 字段（name 是外层 key）
- 不要使用 `NavigationSplitView`（SPM 中不可用）
- 不要在有 .git 的环境中运行（项目目录非 git 仓库）

### 保存 MCP 配置的流程

```
用户点击保存
  → saveServer() 修改内存中的 MCPServerConfig
  → persistServers()
    → 读取现有 ~/.claude.json
    → 重建 "mcpServers" 字典（所有 stdio/sse 服务器）
    → 更新 "projects" 条目（项目级引用和 builtin/plugin 列表）
    → 原子写回（保留所有非 MCP 键）
```

### 同步流程

```
应用启动 / 用户点击"同步"
  → syncFromClaudeJSON()
    → SyncService.syncAll()
      → 读取 ~/.claude.json（全局 mcpServers + 所有项目）
      → 读取 settings.json / settings.local.json（env vars）
      → 解析 enabledPlugins → skillIds
    → 恢复显示别名（从 mcp-display-names.json）
```

## 失败的尝试

| 问题 | 根因 | 解决方案 |
|------|------|----------|
| `NavigationSplitView` 不渲染内容 | SPM 可执行文件限制 | 改用 `HSplitView` |
| `.glassBackgroundEffect` 导致窗口空白 | SPM + WindowGroup 不兼容 | 去掉 `.glassBackgroundEffect` |
| 项目专属 MCP 不显示 | 去重仅用 `name`，全局服务器覆盖了项目服务器 | 使用 `(name, sourceProject)` 组合键去重 |
| `disabledMcpServers` 未处理 | 代码只检查 `disabledMcpjsonServers` | 合并两个键 |
| MCP 保存后修改丢失 | 写入 `~/.claude/mcp.json`，但从 `~/.claude.json` 读取 | 改为读写同一个文件 `~/.claude.json` |
| MCP 测试连接无反馈 | `testServer()` fire-and-forget，后台回调不触发 UI 更新 | 改为 async/await，结构化返回 TestResult |
| 图标缺失 | Info.plist 没有 `CFBundleIconFile` | 添加 `CFBundleIconFile = AppIcon` |
| 中文引号破坏 Swift 编译 | Unicode 书名号被解析为字符串分隔符 | 使用「」日文括号 |
| DMG 挂载 "Read-only file system" | 旧 DMG 仍挂载 | 强制 detach + 唯一卷名 |
| Bun 拦截 shell 命令 | `grep`/`find` 被 Bun 运行时拦截 | 使用 `/usr/bin/grep` 等绝对路径 |

## 待完成

- [x] ~~per-project MCP 服务器编辑后写回 `~/.claude.json` 对应项目条目~~ (v1.9)
- [x] ~~配置文件编辑器支持 `.toml` / `.yaml` 语法高亮~~ (v1.9)
- [x] ~~DMG 背景图 + Finder 图标布局~~ (v1.9)
- [x] ~~应用公证（notarization）脚本~~ (v1.9)
- [x] ~~单元测试~~ (v1.9, 31 tests)
- [ ] 应用公证（notarization）实际执行（需 Apple Developer 账号凭证）
- [ ] 将 MCP 生命周期队列改为并发队列（避免一个进程阻塞所有进程的启停）
- [ ] Keychain 操作增加错误反馈

## 外部依赖

| 工具 | 用途 |
|------|------|
| `python3` + `Pillow` | 图标生成 |
| `iconutil` (系统自带) | PNG→.icns 转换 |
| `swift` (系统自带) | 编译 |
| `codesign` (系统自带) | ad-hoc 签名 |
| `hdiutil` (系统自带) | DMG 创建 |
| `Claude Code CLI` | 被管理的目标应用 |

## 配置路径映射

| 逻辑概念 | 文件系统路径 |
|----------|-------------|
| Claude Code 全局配置 | `~/.claude.json` |
| Claude Code 设置 | `~/.claude/settings.json` |
| 本地覆盖设置 | `~/.claude/settings.local.json` |
| MCP 显示名称别名 | `~/.claude/mcp-display-names.json` |
| 技能目录 | `~/.claude/skills/` |
| Agent 目录 | `~/.claude/agents/` |
| 应用包 | `/Applications/Claude Code Panel.app` |
