# Claude Code Panel

A native macOS management panel for [Claude Code](https://claude.ai) configuration. Built with SwiftUI + Liquid Glass design language, featuring 5 functional panels with a Chinese UI.

> **Windows version**: [ClaudeConsole](https://github.com/RRRadiant/ClaudeConsole)

## Features

| Panel | Description |
|------|-------------|
| **Dashboard** | Claude version detection, model tier status, config stats, update checker |
| **API Config** | Provider switching, API key management, model tier setup, connection test |
| **Config Editor** | Browse and edit `~/.claude.json` / `settings.json` |
| **MCP Servers** | Server CRUD, connection testing, rename aliases, per-project grouping |
| **Skills** | Browse and manage local/plugin skills, install, search |

## Requirements

- macOS 26+ (Lovelace)
- Apple Silicon (arm64)

## Build

```bash
# Build and package DMG
bash scripts/build.sh

# Compile only
swift build -c release --arch arm64 --disable-sandbox
```

Build output goes to `build/`: `.app` bundle + `.dmg` installer.

## Project Structure

```
ClaudeCodePanel/
├── Package.swift                     # SPM manifest
├── scripts/
│   ├── build.sh                      # Build + packaging script
│   └── generate_icon.py              # Icon generator
└── ClaudeCodePanel/
    ├── App/                          # @main entry + AppDelegate
    ├── Models/                       # Data models
    │   ├── APIProvider.swift         # Provider enum + ModelTier
    │   ├── MCPServerConfig.swift     # MCP server model
    │   ├── SkillItem.swift           # Skill model
    │   ├── ClaudeConfig.swift        # Claude Code config
    │   ├── DashboardSummary.swift    # Dashboard aggregate
    │   └── ReleaseInfo.swift         # GitHub Release info
    ├── Services/                     # Service layer (singletons)
    │   ├── ConfigFileService.swift   # JSON file I/O
    │   ├── SyncService.swift         # claude.json -> model sync
    │   ├── MCPService.swift          # MCP process management
    │   ├── UpdateService.swift       # GitHub API update checker
    │   ├── KeychainService.swift     # Keychain API key storage
    │   ├── FileWatcherService.swift  # File change monitoring
    │   └── SkillRepositoryService.swift
    ├── ViewModels/                   # @Observable view models
    │   └── UpdateViewModel.swift     # Update check state machine
    └── Views/                        # SwiftUI views
        ├── ContentView.swift         # Root layout (HSplitView)
        ├── Sidebar/                  # Sidebar navigation
        ├── Dashboard/                # Dashboard panel
        ├── API/                      # API config
        ├── Config/                   # Config file editor
        ├── MCP/                      # MCP server management
        ├── Skills/                   # Skill management
        └── Shared/                   # Shared UI components
```

## Architecture

```
Views (SwiftUI)
    |
ViewModels (@Observable, @MainActor)
    |
Services (singleton)
    |
~/.claude.json   ~/.claude/settings.json   macOS Keychain   GitHub API
```

- **MVVM**: View -> ViewModel -> Service
- **Bidirectional config**: `SyncService.syncAll()` reads `~/.claude.json`, `persistServers()` writes back
- **HSplitView**: Manual split layout (SPM executables don't support `NavigationSplitView`)
- **Auto-update**: Checks GitHub Releases API on launch

## Install

1. Download the latest DMG from [Releases](https://github.com/RRRadiant/ClaudeCodePanel/releases)
2. Mount and drag `Claude Code Panel.app` to `/Applications`
3. If blocked on first launch: System Settings -> Privacy & Security -> Open Anyway

Or run directly:

```bash
open "build/Claude Code Panel.app"
```

## License

[MIT](LICENSE)
