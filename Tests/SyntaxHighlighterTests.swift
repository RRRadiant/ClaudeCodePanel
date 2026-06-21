import Testing
import AppKit
@testable import ClaudeCodePanel

// MARK: - SyntaxHighlighter Tests

@Suite struct SyntaxHighlighterTests {

    // ── TOML ──────────────────────────────────────────────────────────────

    @Test func tomlCommentIsGray() {
        let h = SyntaxHighlighter(fileType: .toml)
        let result = h.highlight("# this is a comment")
        assertColor(.systemGray, in: result, for: "#")
    }

    @Test func tomlSectionIsPurple() {
        let h = SyntaxHighlighter(fileType: .toml)
        let result = h.highlight("[servers]")
        assertColor(.systemPurple, in: result, for: "[")
    }

    @Test func tomlKeyIsBlue() {
        let h = SyntaxHighlighter(fileType: .toml)
        let result = h.highlight("name = \"test\"")
        assertColor(.systemBlue, in: result, for: "n")
    }

    @Test func tomlStringIsGreen() {
        let h = SyntaxHighlighter(fileType: .toml)
        let result = h.highlight("key = \"hello world\"")
        assertColor(.systemGreen, in: result, for: "\"")
    }

    @Test func tomlBooleanIsOrange() {
        let h = SyntaxHighlighter(fileType: .toml)
        let result = h.highlight("enabled = true")
        // Check near the end where "true" appears
        let ns = result.string as NSString
        let range = ns.range(of: "true")
        #expect(range.location != NSNotFound)
        if range.location != NSNotFound {
            let color = result.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor
            #expect(color == .systemOrange)
        }
    }

    @Test func tomlNumberIsOrange() {
        let h = SyntaxHighlighter(fileType: .toml)
        let result = h.highlight("port = 8080")
        let ns = result.string as NSString
        let range = ns.range(of: "8080")
        #expect(range.location != NSNotFound)
        if range.location != NSNotFound {
            let color = result.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor
            #expect(color == .systemOrange)
        }
    }

    // ── YAML ──────────────────────────────────────────────────────────────

    @Test func yamlCommentIsGray() {
        let h = SyntaxHighlighter(fileType: .yaml)
        let result = h.highlight("# comment")
        assertColor(.systemGray, in: result, for: "#")
    }

    @Test func yamlKeyIsBlue() {
        let h = SyntaxHighlighter(fileType: .yaml)
        let result = h.highlight("name: test")
        assertColor(.systemBlue, in: result, for: "n")
    }

    @Test func yamlStringIsGreen() {
        let h = SyntaxHighlighter(fileType: .yaml)
        let result = h.highlight("key: \"value\"")
        assertColor(.systemGreen, in: result, for: "\"")
    }

    @Test func yamlListDashIsPunctuation() {
        let h = SyntaxHighlighter(fileType: .yaml)
        let result = h.highlight("- item1")
        assertColor(.secondaryLabelColor, in: result, for: "-")
    }

    // ── JSON ──────────────────────────────────────────────────────────────

    @Test func jsonStringIsGreen() {
        let h = SyntaxHighlighter(fileType: .json)
        let result = h.highlight("{\"key\": \"value\"}")
        // Find the "value" string
        let ns = result.string as NSString
        let range = ns.range(of: "\"value\"")
        #expect(range.location != NSNotFound)
        if range.location != NSNotFound {
            let color = result.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor
            #expect(color == .systemGreen)
        }
    }

    @Test func jsonNullIsGray() {
        let h = SyntaxHighlighter(fileType: .json)
        let result = h.highlight("{\"key\": null}")
        let ns = result.string as NSString
        let range = ns.range(of: "null")
        #expect(range.location != NSNotFound)
        if range.location != NSNotFound {
            let color = result.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor
            #expect(color == .systemGray)
        }
    }

    @Test func jsonBooleanIsOrange() {
        let h = SyntaxHighlighter(fileType: .json)
        let result = h.highlight("{\"key\": true}")
        let ns = result.string as NSString
        let range = ns.range(of: "true")
        #expect(range.location != NSNotFound)
        if range.location != NSNotFound {
            let color = result.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor
            #expect(color == .systemOrange)
        }
    }

    @Test func jsonNumberIsOrange() {
        let h = SyntaxHighlighter(fileType: .json)
        let result = h.highlight("{\"port\": 8080}")
        let ns = result.string as NSString
        let range = ns.range(of: "8080")
        #expect(range.location != NSNotFound)
        if range.location != NSNotFound {
            let color = result.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor
            #expect(color == .systemOrange)
        }
    }

    @Test func jsonPunctuationIsSecondaryLabel() {
        let h = SyntaxHighlighter(fileType: .json)
        let result = h.highlight("{\"a\": 1}")
        assertColor(.secondaryLabelColor, in: result, for: "{")
    }

    // ── File type detection ───────────────────────────────────────────────

    @Test func syntaxFileTypeDetection() {
        #expect(SyntaxFileType(filename: "config.json") == .json)
        #expect(SyntaxFileType(filename: "settings.toml") == .toml)
        #expect(SyntaxFileType(filename: "data.yaml") == .yaml)
        #expect(SyntaxFileType(filename: "data.yml") == .yaml)
        #expect(SyntaxFileType(filename: "readme.md") == nil)
    }
}

// MARK: - Test helpers

private func assertColor(_ expected: NSColor, in attr: NSAttributedString, for substring: String) {
    let ns = attr.string as NSString
    let range = ns.range(of: substring)
    #expect(range.location != NSNotFound, "Expected '\(substring)' not found in '\(attr.string)'")
    if range.location != NSNotFound {
        let color = attr.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor
        #expect(color == expected, "Expected \(expected) for '\(substring)', got \(String(describing: color))")
    }
}
