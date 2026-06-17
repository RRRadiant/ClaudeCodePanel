import Foundation

@Observable
final class ClaudeConfig: @unchecked Sendable {
    var provider: APIProvider = .anthropic
    var apiKey: String = ""
    var baseURL: String = ""
    var selectedModel: String = ""
    var enabledModels: [String] = []
    var maxTokens: Int = 4096
    var timeout: Int = 120
}
