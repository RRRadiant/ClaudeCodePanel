import SwiftUI
import AppKit

// MARK: - Token types for syntax highlighting

enum SyntaxToken {
    case comment
    case string
    case key
    case section    // TOML [section], YAML top-level keys with no value
    case number
    case boolean
    case null
    case punctuation
    case plain
}

extension SyntaxToken {
    var color: NSColor {
        switch self {
        case .comment:     .systemGray
        case .string:      .systemGreen
        case .key:         .systemBlue
        case .section:     .systemPurple
        case .number:      .systemOrange
        case .boolean:     .systemOrange
        case .null:        .systemGray
        case .punctuation: .secondaryLabelColor
        case .plain:       .labelColor
        }
    }
}

// MARK: - File type detection

enum SyntaxFileType: String {
    case json
    case toml
    case yaml

    init?(filename: String) {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "json": self = .json
        case "toml": self = .toml
        case "yaml", "yml": self = .yaml
        default: return nil
        }
    }
}

// MARK: - Syntax Highlighter

struct SyntaxHighlighter {
    let fileType: SyntaxFileType

    func highlight(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: text.utf16.count)

        // Base font + color
        let baseFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        result.addAttribute(.font, value: baseFont, range: range)
        result.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)

        // Apply token highlighting
        let tokens = tokenize(text)
        for (tokenRange, tokenType) in tokens {
            guard tokenType != .plain else { continue }
            result.addAttribute(.foregroundColor, value: tokenType.color, range: tokenRange)
        }

        return result
    }

    // MARK: - Tokenizer

    private func tokenize(_ text: String) -> [(NSRange, SyntaxToken)] {
        switch fileType {
        case .toml: return tokenizeTOML(text)
        case .yaml: return tokenizeYAML(text)
        case .json: return tokenizeJSON(text)
        }
    }

    // ── TOML ──────────────────────────────────────────────────────────────

    private func tokenizeTOML(_ text: String) -> [(NSRange, SyntaxToken)] {
        var tokens: [(NSRange, SyntaxToken)] = []
        let ns = text as NSString
        let lines = text.components(separatedBy: .newlines)
        var offset = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lineLen = (line as NSString).length

            // Full-line comment
            if trimmed.hasPrefix("#") {
                tokens.append((NSRange(location: offset, length: lineLen), .comment))
                offset += lineLen + 1
                continue
            }

            // Section header [section.name]
            if let sectionEnd = line.range(of: "]")?.lowerBound,
               let sectionStart = line.firstIndex(of: "["),
               sectionStart < sectionEnd {
                let secRange = NSRange(
                    location: offset + line.distance(from: line.startIndex, to: sectionStart),
                    length: line.distance(from: sectionStart, to: sectionEnd) + 1
                )
                tokens.append((secRange, .section))

                // Inline comment after section
                if let commentStart = line.range(of: "#")?.lowerBound {
                    let commentLoc = offset + line.distance(from: line.startIndex, to: commentStart)
                    tokens.append((NSRange(location: commentLoc, length: lineLen - (commentLoc - offset)), .comment))
                }
                offset += lineLen + 1
                continue
            }

            // Key = value line
            if let eqIdx = line.firstIndex(of: "=") {
                let keyEnd = line.distance(from: line.startIndex, to: eqIdx)
                tokens.append((NSRange(location: offset, length: keyEnd), .key))
                tokens.append((NSRange(location: offset + keyEnd, length: 1), .punctuation))

                // Value part
                let valueStart = line.index(after: eqIdx)
                if valueStart < line.endIndex {
                    let valueStr = String(line[valueStart...])
                    let valueOffset = offset + line.distance(from: line.startIndex, to: valueStart)
                    tokens.append(contentsOf: highlightValue(valueStr, at: valueOffset))
                }

                // Inline comment
                if let commentStart = line.range(of: "#")?.lowerBound {
                    let commentLoc = offset + line.distance(from: line.startIndex, to: commentStart)
                    tokens.append((NSRange(location: commentLoc, length: lineLen - (commentLoc - offset)), .comment))
                }
                offset += lineLen + 1
                continue
            }

            // Inline comment in otherwise plain line
            if let commentStart = line.range(of: "#")?.lowerBound {
                let commentLoc = offset + line.distance(from: line.startIndex, to: commentStart)
                tokens.append((NSRange(location: commentLoc, length: lineLen - (commentLoc - offset)), .comment))
            }

            offset += lineLen + 1
        }

        return tokens
    }

    // ── YAML ──────────────────────────────────────────────────────────────

    private func tokenizeYAML(_ text: String) -> [(NSRange, SyntaxToken)] {
        var tokens: [(NSRange, SyntaxToken)] = []
        let ns = text as NSString
        let lines = text.components(separatedBy: .newlines)
        var offset = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lineLen = (line as NSString).length

            // Full-line comment
            if trimmed.hasPrefix("#") {
                tokens.append((NSRange(location: offset, length: lineLen), .comment))
                offset += lineLen + 1
                continue
            }

            // List item: - value
            if trimmed.hasPrefix("- ") {
                if let dashIdx = line.firstIndex(of: "-") {
                    let dashPos = line.distance(from: line.startIndex, to: dashIdx)
                    tokens.append((NSRange(location: offset + dashPos, length: 1), .punctuation))
                }
                offset += lineLen + 1
                continue
            }

            // Key: value (or key:)
            if let colonIdx = line.firstIndex(of: ":") {
                let keyEnd = line.distance(from: line.startIndex, to: colonIdx)
                // Only highlight as key if it looks like a key (not URL, not inline JSON)
                let keyCandidate = String(line[line.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces)
                if !keyCandidate.contains("://") && !keyCandidate.contains("{") {
                    tokens.append((NSRange(location: offset, length: keyEnd), .key))
                    tokens.append((NSRange(location: offset + keyEnd, length: 1), .punctuation))

                    let valueStart = line.index(after: colonIdx)
                    if valueStart < line.endIndex {
                        let valueStr = String(line[valueStart...]).trimmingCharacters(in: .whitespaces)
                        let valueIdx = line.distance(from: line.startIndex, to: valueStart)
                            + (String(line[valueStart...]).count - String(line[valueStart...]).trimmingCharacters(in: .whitespaces).count)
                        let valueOffset = offset + valueIdx
                        tokens.append(contentsOf: highlightValue(valueStr, at: valueOffset))
                    }
                }

                // Inline comment
                if let commentStart = line.range(of: "#")?.lowerBound {
                    let commentLoc = offset + line.distance(from: line.startIndex, to: commentStart)
                    tokens.append((NSRange(location: commentLoc, length: lineLen - (commentLoc - offset)), .comment))
                }
                offset += lineLen + 1
                continue
            }

            // Inline comment
            if let commentStart = line.range(of: "#")?.lowerBound {
                let commentLoc = offset + line.distance(from: line.startIndex, to: commentStart)
                tokens.append((NSRange(location: commentLoc, length: lineLen - (commentLoc - offset)), .comment))
            }

            offset += lineLen + 1
        }

        return tokens
    }

    // ── JSON ──────────────────────────────────────────────────────────────

    private func tokenizeJSON(_ text: String) -> [(NSRange, SyntaxToken)] {
        var tokens: [(NSRange, SyntaxToken)] = []
        let ns = text as NSString
        var i = 0

        /// Safely create a Character from a UTF-16 code unit.
        func safeChar(_ codeUnit: unichar) -> Character? {
            UnicodeScalar(codeUnit).map(Character.init)
        }

        while i < ns.length {
            guard let ch = safeChar(ns.character(at: i)) else { i += 1; continue }

            // String
            if ch == "\"" {
                if let end = findStringEnd(in: ns, from: i + 1) {
                    let len = end - i + 1
                    tokens.append((NSRange(location: i, length: len), .string))
                    i = end + 1
                    continue
                }
            }

            // Numbers
            let nextChar = i + 1 < ns.length ? safeChar(ns.character(at: i + 1)) : nil
            if ch.isNumber || (ch == "-" && nextChar?.isNumber == true) {
                let start = i
                var j = i
                if ns.character(at: j) == ("-" as Character).asciiValue! { j += 1 }
                while j < ns.length, let c = safeChar(ns.character(at: j)) {
                    if c.isNumber || c == "." || c == "e" || c == "E" || c == "+" || c == "-" { j += 1 }
                    else { break }
                }
                tokens.append((NSRange(location: start, length: j - start), .number))
                i = j
                continue
            }

            // Keywords: true, false, null
            let remaining = ns.substring(from: i)
            for kw in ["true", "false", "null"] {
                if remaining.hasPrefix(kw) {
                    let after = i + kw.count
                    let afterChar = after < ns.length ? safeChar(ns.character(at: after)) : nil
                    let isWordBoundary = after >= ns.length
                        || afterChar?.isLetter == false
                    if isWordBoundary {
                        let token: SyntaxToken = (kw == "null") ? .null : .boolean
                        tokens.append((NSRange(location: i, length: kw.count), token))
                        i += kw.count
                        break
                    }
                }
            }

            // Punctuation: { } [ ] : ,
            if "{}[]:,".contains(ch) {
                tokens.append((NSRange(location: i, length: 1), .punctuation))
            }

            i += 1
        }

        return tokens
    }

    // MARK: - Value highlighting (TOML / YAML)

    private func highlightValue(_ value: String, at baseOffset: Int) -> [(NSRange, SyntaxToken)] {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let leadingWS = value.count - value.trimmingCharacters(in: CharacterSet(charactersIn: " ")).count
        let offset = baseOffset + (value.count - trimmed.count - leadingWS)

        // String
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\""))
            || (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            return [(NSRange(location: offset, length: trimmed.count), .string)]
        }

        // Boolean / null
        switch trimmed.lowercased() {
        case "true", "false": return [(NSRange(location: offset, length: trimmed.count), .boolean)]
        case "null", "nil", "~": return [(NSRange(location: offset, length: trimmed.count), .null)]
        default: break
        }

        // Number
        if let _ = Double(trimmed) {
            return [(NSRange(location: offset, length: trimmed.count), .number)]
        }

        return []
    }

    private func findStringEnd(in ns: NSString, from start: Int) -> Int? {
        var i = start
        let backslash = ("\\" as Character).asciiValue!
        let quote = ("\"" as Character).asciiValue!
        while i < ns.length {
            let ch = ns.character(at: i)
            if ch == backslash { i += 2; continue }
            if ch == quote { return i }
            i += 1
        }
        return nil
    }
}
