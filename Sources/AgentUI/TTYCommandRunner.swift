import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

struct PTYResult { let text: String }

enum PTYError: LocalizedError {
    case openFailed
    case launchFailed(String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .openFailed: return "openpty failed"
        case let .launchFailed(msg): return "Failed to launch: \(msg)"
        case .timedOut: return "PTY timed out"
        }
    }
}

struct TTYCommandRunner {
    struct Options {
        var rows: UInt16 = 60
        var cols: UInt16 = 200
        var timeout: TimeInterval = 15
        var extraArgs: [String] = []
    }

    static func enrichedEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        let defaults = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            "\(home)/.local/bin",
            "\(home)/.cargo/bin",
            "\(home)/.npm-global/bin",
        ]
        var merged = defaults + (env["PATH"]?.split(separator: ":").map(String.init) ?? [])
        var seen = Set<String>()
        merged = merged.filter { if seen.contains($0) { return false } else { seen.insert($0); return true } }
        env["PATH"] = merged.joined(separator: ":")
        env["TERM"] = env["TERM"] ?? "xterm-256color"
        env["LANG"] = env["LANG"] ?? "en_US.UTF-8"
        return env
    }

    func runCodexStatus(timeout: TimeInterval = 18) throws -> PTYResult {
        var master: Int32 = -1
        var slave: Int32 = -1
        var ws = winsize(ws_row: 60, ws_col: 200, ws_xpixel: 0, ws_ypixel: 0)
        guard openpty(&master, &slave, nil, nil, &ws) == 0 else { throw PTYError.openFailed }
        // non-blocking reads
        _ = fcntl(master, F_SETFL, O_NONBLOCK)

        let masterHandle = FileHandle(fileDescriptor: master, closeOnDealloc: true)
        let slaveHandle = FileHandle(fileDescriptor: slave, closeOnDealloc: true)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["codex", "-s", "read-only", "-a", "untrusted"]
        proc.standardInput = slaveHandle
        proc.standardOutput = slaveHandle
        proc.standardError = slaveHandle
        proc.environment = Self.enrichedEnvironment()
        // Set working directory to Documents to avoid "/" approval prompt
        proc.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")

        do { try proc.run() } catch { throw PTYError.launchFailed(error.localizedDescription) }
        defer {
            if proc.isRunning { proc.terminate() }
            try? masterHandle.close()
            try? slaveHandle.close()
        }

        func send(_ s: String) {
            if let data = s.data(using: .utf8) { _ = data.withUnsafeBytes { write(master, $0.baseAddress, data.count) } }
        }

        func readAll() -> Data {
            var out = Data()
            while true {
                var tmp = [UInt8](repeating: 0, count: 8192)
                let n = read(master, &tmp, tmp.count)
                if n > 0 { out.append(contentsOf: tmp.prefix(n)); continue }
                break
            }
            return out
        }

        let cpr1 = Data([0x1B, 0x5B, 0x36, 0x6E])      // ESC[6n
        let cpr2 = Data([0x1B, 0x5B, 0x3F, 0x36, 0x6E]) // ESC[?6n
        let statusMarkers: [Data] = [
            "5h limit",
            "5-hour limit",
            "Session limit",
            "session limit",
            "Session window",
            "session window",
            "Weekly limit",
            "weekly limit",
            "Weekly window",
            "weekly window",
        ].map { Data($0.utf8) }
        let modelPromptMarker = Data("Choose how you'd like Codex to proceed".utf8)
        let modelTryMarker = Data("Try new model".utf8)
        let modelExistingMarker = Data("Use existing model".utf8)
        var buffer = Data()
        var sawStatus = false
        var handledModelPrompt = false
        let deadline = Date().addingTimeInterval(timeout)

        // Helper: read output and respond to any cursor position requests immediately
        func readAndRespondToCPR() {
            let chunk = readAll()
            if !chunk.isEmpty {
                buffer.append(chunk)
                // Check for CPR requests and respond immediately
                if buffer.range(of: cpr1) != nil || buffer.range(of: cpr2) != nil {
                    send("\u{1b}[1;1R")
                }
            }
        }

        // Helper: wait with CPR handling
        func waitWithCPR(_ microseconds: UInt32) {
            let iterations = Int(microseconds / 50_000)  // Check every 50ms
            for _ in 0..<max(1, iterations) {
                readAndRespondToCPR()
                usleep(50_000)
            }
        }

        // Wait for TUI to fully initialize - look for the welcome box
        let welcomeMarkers: [Data] = [
            "To get started",
            "OpenAI Codex",
            "Codex (v",
            "Tip:",
        ].map { Data($0.utf8) }
        var ready = false
        let initDeadline = Date().addingTimeInterval(8.0)

        while Date() < initDeadline && !ready {
            readAndRespondToCPR()
            if welcomeMarkers.contains(where: { buffer.range(of: $0) != nil }) {
                ready = true
            }
            // Also check for approval prompt
            let approvalPrompt = Data("Require approval".utf8)
            if buffer.range(of: approvalPrompt) != nil {
                send("\r")
                waitWithCPR(500_000)
            }
            if !handledModelPrompt,
               (buffer.range(of: modelPromptMarker) != nil ||
                   (buffer.range(of: modelTryMarker) != nil && buffer.range(of: modelExistingMarker) != nil)) {
                handledModelPrompt = true
                // Accept the current selection to dismiss the prompt.
                send("\r")
                waitWithCPR(800_000)
            }
            usleep(100_000)
        }

        // Wait a bit more after welcome appears
        waitWithCPR(500_000)

        // Send /status command
        send("/status")
        waitWithCPR(200_000)
        send("\r")  // Enter to execute
        waitWithCPR(2_000_000)

        // Main loop - wait for status output
        while Date() < deadline {
            readAndRespondToCPR()
            if !sawStatus, statusMarkers.contains(where: { buffer.range(of: $0) != nil }) {
                sawStatus = true
                waitWithCPR(500_000)
                break
            }
            usleep(100_000)
        }

        // If we didn't see status markers, try sending /status again
        if !sawStatus && Date() < deadline {
            send("\u{1b}")  // ESC to clear any state
            waitWithCPR(200_000)
            send("/status\n")
            waitWithCPR(3_000_000)
        }

        guard !buffer.isEmpty else { throw PTYError.timedOut }
        let text = String(data: buffer, encoding: .utf8) ?? ""
        return PTYResult(text: text)
    }
}
