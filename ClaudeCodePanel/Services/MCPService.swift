import Foundation

final class MCPService: @unchecked Sendable {
    static let shared = MCPService()

    /// Concurrent queue — each process gets its own lifecycle without blocking others.
    private let queue = DispatchQueue(label: "com.claudecodepanel.mcp", attributes: .concurrent)
    /// Synchronized access to the processes dictionary.
    private let lock = NSLock()
    private var _processes: [UUID: Process] = [:]
    private var processes: [UUID: Process] {
        get { lock.withLock { _processes } }
        set { lock.withLock { _processes = newValue } }
    }

    // MARK: - Long-running server management

    func startServer(_ config: MCPServerConfig, onStatusChange: @escaping @MainActor (MCPServerConfig.MCPServerStatus) -> Void) {
        guard config.serverType == .stdio else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [config.command] + config.args

        var env = ProcessInfo.processInfo.environment
        for (key, value) in config.env {
            env[key] = value
        }
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        // Use terminationHandler for async exit handling — never blocks a queue
        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                onStatusChange(.stopped)
            }
            self?.lock.withLock {
                self?._processes[config.id] = nil
            }
        }

        do {
            try process.run()
            lock.withLock { _processes[config.id] = process }
            Task { @MainActor in
                onStatusChange(.running)
            }
        } catch {
            Task { @MainActor in
                onStatusChange(.error)
            }
        }
    }

    func stopServer(_ config: MCPServerConfig) {
        let process = lock.withLock { _processes[config.id] }
        guard let process, process.isRunning else { return }
        process.terminate()
        lock.withLock { _processes[config.id] = nil }
    }

    // MARK: - Connection tests (return results for UI display)

    struct TestResult {
        let success: Bool
        let message: String
        let detail: String?  // e.g. PID, HTTP status, error details
    }

    /// Test an SSE endpoint by sending an HTTP GET and checking the response.
    func testSSE(urlString: String, timeout: TimeInterval = 8) async -> TestResult {
        guard let url = URL(string: urlString) else {
            return TestResult(success: false, message: "无效的 URL", detail: urlString)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return TestResult(success: false, message: "非 HTTP 响应", detail: nil)
            }
            if (200...299).contains(http.statusCode) {
                let mime = (http.mimeType).map { " · \($0)" } ?? ""
                return TestResult(
                    success: true,
                    message: "连接成功 · HTTP \(http.statusCode)\(mime)",
                    detail: url.absoluteString
                )
            } else if http.statusCode < 500 {
                return TestResult(
                    success: true,
                    message: "可访问 · HTTP \(http.statusCode)",
                    detail: "服务器返回非 2xx 状态，但端点可达"
                )
            } else {
                return TestResult(
                    success: false,
                    message: "服务器错误 · HTTP \(http.statusCode)",
                    detail: url.absoluteString
                )
            }
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                return TestResult(success: false, message: "连接超时", detail: "\(timeout)秒无响应")
            case .cannotConnectToHost, .cannotFindHost:
                return TestResult(success: false, message: "无法连接主机", detail: error.failingURL?.absoluteString ?? urlString)
            case .notConnectedToInternet:
                return TestResult(success: false, message: "无网络连接", detail: nil)
            default:
                return TestResult(success: false, message: "连接失败", detail: error.localizedDescription)
            }
        } catch {
            return TestResult(success: false, message: "请求失败", detail: error.localizedDescription)
        }
    }

    /// Test a STDIO server by launching the process and seeing if it stays alive.
    func testSTDIO(command: String, args: [String], env: [String: String] = [:], waitSeconds: Double = 3) async -> TestResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + args

        var processEnv = ProcessInfo.processInfo.environment
        for (key, value) in env {
            processEnv[key] = value
        }
        process.environment = processEnv

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Check if the command exists on PATH
        let whichTask = Process()
        whichTask.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichTask.arguments = [command]
        let whichPipe = Pipe()
        whichTask.standardOutput = whichPipe
        whichTask.standardError = FileHandle.nullDevice
        try? whichTask.run()
        whichTask.waitUntilExit()

        guard whichTask.terminationStatus == 0 else {
            return TestResult(
                success: false,
                message: "找不到命令",
                detail: "command not found: \(command)"
            )
        }
        let resolvedPath = String(data: whichPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? command

        // Launch the process
        do {
            try process.run()
        } catch {
            return TestResult(
                success: false,
                message: "启动失败",
                detail: error.localizedDescription
            )
        }

        let pid = process.processIdentifier

        do {
            try await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))
        } catch {
            if process.isRunning {
                process.terminate()
            }
            return TestResult(success: false, message: "测试被取消", detail: "PID \(pid) 已终止")
        }

        if process.isRunning {
            process.terminate()
            let stderrData = try? stderrPipe.fileHandleForReading.readToEnd()
            let stderrStr = stderrData.flatMap { String(data: $0, encoding: .utf8) }?
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""

            var detail = "PID \(pid) · \(resolvedPath)"
            if !stderrStr.isEmpty {
                detail += "\nstderr: \(stderrStr.prefix(200))"
            }
            return TestResult(success: true, message: "进程启动成功", detail: detail)
        } else {
            let exitCode = process.terminationStatus
            let stderrData = try? stderrPipe.fileHandleForReading.readToEnd()
            let stderrStr = stderrData.flatMap { String(data: $0, encoding: .utf8) }?
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""

            var detail = "exit code \(exitCode)"
            if !stderrStr.isEmpty { detail += "\n\(stderrStr.prefix(300))" }
            return TestResult(success: false, message: "进程立即退出", detail: detail)
        }
    }
}
