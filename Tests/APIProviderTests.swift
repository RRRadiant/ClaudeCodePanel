import Testing
@testable import ClaudeCodePanel

// MARK: - APIProvider + ModelTier Tests

@Suite struct APIProviderTests {

    @Test func anthropicKnownModelsNotEmpty() {
        let models = APIProvider.anthropic.knownModels
        #expect(models[.opus]?.isEmpty == false)
        #expect(models[.sonnet]?.isEmpty == false)
        #expect(models[.haiku]?.isEmpty == false)
    }

    @Test func customProviderHasNoKnownModels() {
        let models = APIProvider.custom.knownModels
        #expect(models.isEmpty)
    }

    @Test func allKnownModelsFlattened() {
        let all = APIProvider.anthropic.allKnownModels
        #expect(all.contains("claude-opus-4-8-20250514"))
        #expect(all.contains("claude-sonnet-4-6-20250514"))
        #expect(all.contains("claude-haiku-4-5"))
    }

    @Test func defaultBaseURLs() {
        #expect(APIProvider.anthropic.defaultBaseURL == "https://api.anthropic.com")
        #expect(APIProvider.openai.defaultBaseURL == "https://api.openai.com")
        #expect(APIProvider.deepseek.defaultBaseURL == "https://api.deepseek.com")
        #expect(APIProvider.custom.defaultBaseURL == "")
    }

    @Test func modelTierEnvKeys() {
        #expect(ModelTier.opus.envKey == "ANTHROPIC_DEFAULT_OPUS_MODEL")
        #expect(ModelTier.sonnet.envKey == "ANTHROPIC_DEFAULT_SONNET_MODEL")
        #expect(ModelTier.haiku.envKey == "ANTHROPIC_DEFAULT_HAIKU_MODEL")
    }

    @Test func modelTierAllCasesCount() {
        #expect(ModelTier.allCases.count == 3)
    }

    @Test func APITierMapping() {
        // Opus → premium models
        #expect(APIProvider.anthropic.knownModels[.opus]?.contains("claude-opus-4-8-20250514") == true)
        // Haiku → fast models
        #expect(APIProvider.anthropic.knownModels[.haiku]?.contains("claude-haiku-4-5") == true)
    }
}
