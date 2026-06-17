import Foundation
import Observation

@MainActor
@Observable
final class APIConfigViewModel {
    var provider: APIProvider = .anthropic
    var apiKey: String = ""
    var baseURL: String = ""
    var selectedModel: String = ""
    var enabledModels: [String] = []
    var detectedModels: [String] = []
    var isDetectingModels: Bool = false
    var isSaving: Bool = false
    var isTestingConnection: Bool = false
    var connectionStatus: ConnectionStatus = .unknown
    var errorMessage: String?
    var successMessage: String?

    enum ConnectionStatus {
        case unknown
        case testing
        case connected
        case failed(String)
    }

    // Model tier config — maps to ANTHROPIC_DEFAULT_{TIER}_MODEL env vars
    var tierModels: [ModelTier: String] = [:]

    private let configService = ConfigFileService.shared

    func loadConfig() {
        let synced = SyncService.shared.syncAll()
        provider = synced.provider
        apiKey = synced.apiKey
        baseURL = synced.baseURL
        selectedModel = synced.selectedModel
        enabledModels = synced.enabledModels

        if baseURL.isEmpty {
            baseURL = provider.defaultBaseURL
        }

        // Tier models from SyncService (already merged settings + local overrides)
        tierModels = synced.tierModels
        // Fallback: use provider defaults for missing tiers
        for tier in ModelTier.allCases {
            if tierModels[tier]?.isEmpty ?? true {
                tierModels[tier] = defaultModelForTier(tier)
            }
        }

        // Set selected from ANTHROPIC_MODEL env if present
        if selectedModel.isEmpty {
            selectedModel = tierModels[.sonnet] ?? ""
        }
    }

    func saveConfig() {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        var currentSettings = (try? configService.readJSON(at: configService.settingsPath)) ?? [:]
        var env = currentSettings["env"] as? [String: String] ?? [:]

        env["ANTHROPIC_AUTH_TOKEN"] = apiKey
        env["ANTHROPIC_BASE_URL"] = baseURL
        env["ANTHROPIC_MODEL"] = selectedModel

        // Save tier models
        for tier in ModelTier.allCases {
            if let model = tierModels[tier], !model.isEmpty {
                env[tier.envKey] = model
            }
        }

        currentSettings["env"] = env

        do {
            try configService.writeJSON(currentSettings, to: configService.settingsPath)
            successMessage = "配置已保存"
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
        }

        isSaving = false
    }

    func detectModels() async {
        guard !apiKey.isEmpty else {
            errorMessage = "请先填写 API Key"
            return
        }

        isDetectingModels = true
        errorMessage = nil
        detectedModels = []

        let modelsURL = baseURL.hasSuffix("/") ? "\(baseURL)v1/models" : "\(baseURL)/v1/models"

        guard let url = URL(string: modelsURL) else {
            errorMessage = "无效的 Base URL"
            isDetectingModels = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["data"] as? [[String: Any]] {
                detectedModels = models.compactMap { $0["id"] as? String }.sorted()
                if detectedModels.isEmpty {
                    errorMessage = "未检测到模型"
                }
            } else {
                errorMessage = "无效的响应格式"
            }
        } catch {
            errorMessage = "模型检测失败: \(error.localizedDescription)"
        }

        isDetectingModels = false
    }

    func autoAssignModels() {
        // Auto-assign detected models to tiers based on name heuristics
        for tier in ModelTier.allCases {
            let match = detectedModels.first { model in
                let lower = model.lowercased()
                switch tier {
                case .opus: return lower.contains("opus") || lower.contains("pro") || lower.contains("v4")
                case .sonnet: return lower.contains("sonnet") || lower.contains("v4-pro")
                case .haiku: return lower.contains("haiku") || lower.contains("flash") || lower.contains("mini")
                }
            }
            if let match {
                tierModels[tier] = match
            }
        }

        if let first = detectedModels.first {
            if selectedModel.isEmpty {
                selectedModel = tierModels[.sonnet] ?? tierModels[.opus] ?? first
            }
            enabledModels = detectedModels
        }
    }

    func testConnection() async {
        guard !apiKey.isEmpty else {
            connectionStatus = .failed("请先填写 API Key")
            return
        }

        isTestingConnection = true
        connectionStatus = .testing

        let modelsURL = baseURL.hasSuffix("/") ? "\(baseURL)v1/models" : "\(baseURL)/v1/models"
        guard let url = URL(string: modelsURL) else {
            connectionStatus = .failed("无效的 URL")
            isTestingConnection = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 200 {
                    connectionStatus = .connected
                } else {
                    connectionStatus = .failed("HTTP \(http.statusCode)")
                }
            }
        } catch {
            connectionStatus = .failed(error.localizedDescription)
        }

        isTestingConnection = false
    }

    func importDetectedModel() {
        autoAssignModels()
    }

    private func defaultModelForTier(_ tier: ModelTier) -> String {
        return provider.knownModels[tier]?.first ?? ""
    }
}
