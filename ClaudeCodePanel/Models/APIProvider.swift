import Foundation
import SwiftUI

enum APIProvider: String, CaseIterable, Codable {
    case anthropic
    case openai
    case deepseek
    case custom

    var displayName: String {
        switch self {
        case .anthropic: "Anthropic"
        case .openai: "OpenAI"
        case .deepseek: "DeepSeek"
        case .custom: "自定义"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .anthropic: "https://api.anthropic.com"
        case .openai: "https://api.openai.com"
        case .deepseek: "https://api.deepseek.com"
        case .custom: ""
        }
    }

    /// Known model IDs for each provider, organized by tier
    var knownModels: [ModelTier: [String]] {
        switch self {
        case .anthropic:
            return [
                .opus: [
                    "claude-opus-4-8-20250514",
                    "claude-opus-4-8",
                    "claude-opus-4-5",
                ],
                .sonnet: [
                    "claude-sonnet-4-6-20250514",
                    "claude-sonnet-4-6",
                    "claude-sonnet-4-5",
                ],
                .haiku: [
                    "claude-haiku-4-5-20251001",
                    "claude-haiku-4-5",
                ],
            ]
        case .openai:
            return [
                .opus: ["gpt-4o", "gpt-4-turbo"],
                .sonnet: ["gpt-4o-mini"],
                .haiku: ["gpt-4o-mini"],
            ]
        case .deepseek:
            return [
                .opus: ["deepseek-v4-pro"],
                .sonnet: ["deepseek-v4-pro"],
                .haiku: ["deepseek-v4-flash"],
            ]
        case .custom:
            return [:]
        }
    }

    /// All known models flattened
    var allKnownModels: [String] {
        var models: [String] = []
        for tier in ModelTier.allCases {
            models.append(contentsOf: knownModels[tier] ?? [])
        }
        return models
    }
}

enum ModelTier: String, CaseIterable, Codable {
    case opus = "Opus"
    case sonnet = "Sonnet"
    case haiku = "Haiku"

    var displayName: String {
        switch self {
        case .opus: "Opus · 最强"
        case .sonnet: "Sonnet · 均衡"
        case .haiku: "Haiku · 快速"
        }
    }

    var shortName: String {
        switch self {
        case .opus: "Opus"
        case .sonnet: "Sonnet"
        case .haiku: "Haiku"
        }
    }

    var envKey: String {
        switch self {
        case .opus: "ANTHROPIC_DEFAULT_OPUS_MODEL"
        case .sonnet: "ANTHROPIC_DEFAULT_SONNET_MODEL"
        case .haiku: "ANTHROPIC_DEFAULT_HAIKU_MODEL"
        }
    }

    var icon: String {
        switch self {
        case .opus: "sparkles"
        case .sonnet: "circle.grid.2x2"
        case .haiku: "bolt.fill"
        }
    }

    var color: Color {
        switch self {
        case .opus: .purple
        case .sonnet: .blue
        case .haiku: .green
        }
    }
}
