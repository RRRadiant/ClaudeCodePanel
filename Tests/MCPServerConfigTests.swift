import Testing
@testable import ClaudeCodePanel

// MARK: - MCPServerConfig Tests

@Suite struct MCPServerConfigTests {

    @Test func stdioFromJSON() {
        let dict: [String: Any] = [
            "name": "filesystem",
            "type": "stdio",
            "command": "npx",
            "args": ["-y", "@anthropic/mcp-filesystem"],
            "env": ["HOME": "/Users/test"]
        ]
        let config = MCPServerConfig.fromJSON(dict)
        #expect(config != nil)
        #expect(config?.name == "filesystem")
        #expect(config?.serverType == .stdio)
        #expect(config?.command == "npx")
        #expect(config?.args == ["-y", "@anthropic/mcp-filesystem"])
        #expect(config?.env == ["HOME": "/Users/test"])
    }

    @Test func sseFromJSON() {
        let dict: [String: Any] = [
            "name": "remote-server",
            "type": "sse",
            "url": "http://localhost:8080/sse"
        ]
        let config = MCPServerConfig.fromJSON(dict)
        #expect(config != nil)
        #expect(config?.serverType == .sse)
        #expect(config?.url == "http://localhost:8080/sse")
    }

    @Test func stdioToJSONEntry() {
        let config = MCPServerConfig(
            name: "test-server",
            serverType: .stdio,
            command: "node",
            args: ["server.js"],
            env: ["NODE_ENV": "production"]
        )
        let entry = config.toClaudeJSONEntry()
        #expect(entry["type"] as? String == "stdio")
        #expect(entry["command"] as? String == "node")
        #expect(entry["args"] as? [String] == ["server.js"])
        #expect((entry["env"] as? [String: String])?["NODE_ENV"] == "production")
        // Name must NOT be in the entry dict
        #expect(entry["name"] == nil)
    }

    @Test func sseToJSONEntry() {
        let config = MCPServerConfig(
            name: "remote",
            serverType: .sse,
            url: "https://api.example.com/sse"
        )
        let entry = config.toClaudeJSONEntry()
        #expect(entry["type"] as? String == "sse")
        #expect(entry["url"] as? String == "https://api.example.com/sse")
    }

    @Test func displayNameUsesAliasWhenSet() {
        let config = MCPServerConfig(name: "orig", displayAlias: "自定义名称")
        #expect(config.displayName == "自定义名称")
        #expect(config.isRenamed == true)
    }

    @Test func displayNameFallsBackToName() {
        let config = MCPServerConfig(name: "orig")
        #expect(config.displayName == "orig")
        #expect(config.isRenamed == false)
    }

    @Test func sourceLabelExtractsLastPathComponent() {
        let config = MCPServerConfig(name: "srv", sourceProject: "/Users/test/my-project")
        #expect(config.sourceLabel == "my-project")
    }

    @Test func globalServerHasNilSourceLabel() {
        let config = MCPServerConfig(name: "global")
        #expect(config.sourceLabel == nil)
    }
}
