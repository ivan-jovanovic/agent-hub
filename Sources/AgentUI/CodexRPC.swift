import Foundation

// Minimal JSON-RPC client for Codex CLI `app-server` over stdin/stdout.
// Starts a short-lived Codex RPC process and requests rate limits.
enum CodexRPCError: LocalizedError {
    case startFailed(String)
    case requestFailed(String)
    case malformed(String)

    var errorDescription: String? {
        switch self {
        case let .startFailed(msg): return "Codex RPC start failed: \(msg)"
        case let .requestFailed(msg): return "Codex RPC request failed: \(msg)"
        case let .malformed(msg): return "Codex RPC malformed response: \(msg)"
        }
    }
}

struct CodexRPCRateLimits: Decodable {
    struct Window: Decodable { let usedPercent: Double?; let windowDurationMins: Int?; let resetsAt: Int? }
    struct Credits: Decodable { let hasCredits: Bool?; let unlimited: Bool?; let balance: String? }
    let primary: Window?
    let secondary: Window?
    let credits: Credits?
}

private struct RPCRateLimitsResult: Decodable { let rateLimits: CodexRPCRateLimits }
private struct RPCEnvelope: Decodable { let id: Int?; let result: RPCRateLimitsResult?; let error: RPCErrorPayload? }
private struct RPCErrorPayload: Decodable { let code: Int?; let message: String? }

final class CodexRPCClient {
    private let process = Process()
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private var nextID = 1
    private var stdoutBuffer = Data()

    init(codexBinary: String = "codex") throws {
        // Resolve codex via PATH; use /usr/bin/env to honor PATH resolution.
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = CodexRPCClient.effectivePATH(baseline: env["PATH"])

        self.process.environment = env
        self.process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        self.process.arguments = [codexBinary, "-s", "read-only", "-a", "untrusted", "app-server"]
        self.process.standardInput = self.stdinPipe
        self.process.standardOutput = self.stdoutPipe
        self.process.standardError = self.stderrPipe
        do {
            try self.process.run()
        } catch {
            throw CodexRPCError.startFailed(error.localizedDescription)
        }

        // Drain an initial stderr chunk (avoid blocking if pipe fills); ignore content.
        _ = self.stderrPipe.fileHandleForReading.availableData
    }

    deinit { self.shutdown() }

    func initialize(clientName: String, clientVersion: String) async throws {
        // Some Codex versions may not require/understand initialize; send a best‑effort notification only.
        try self.sendNotification(method: "initialized", params: [
            "clientInfo": ["name": clientName, "version": clientVersion],
        ])
    }

    func fetchRateLimits() async throws -> CodexRPCRateLimits {
        let raw = try await self.request(method: "account/rateLimits/read")
        do {
            let data = try JSONSerialization.data(withJSONObject: raw)
            let decoded = try JSONDecoder().decode(RPCRateLimitsResult.self, from: data)
            return decoded.rateLimits
        } catch {
            throw CodexRPCError.malformed(error.localizedDescription)
        }
    }

    func shutdown() {
        if self.process.isRunning { self.process.terminate() }
    }

    // MARK: - JSON-RPC helpers

    private func request(method: String, params: [String: Any]? = nil) async throws -> [String: Any] {
        let id = self.nextID
        self.nextID += 1
        try self.sendRequest(id: id, method: method, params: params)
        // Keep RPC snappy; if Codex RPC isn't available, we fall back to PTY.
        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline {
            if let message = try await self.readNextJSONLine(timeout: 2.0) {
                if let mid = (message["id"] as? NSNumber)?.intValue, mid == id {
                    if let err = message["error"] as? [String: Any] {
                        let msg = (err["message"] as? String) ?? "Unknown RPC error"
                        throw CodexRPCError.requestFailed(msg)
                    }
                    if let res = message["result"] as? [String: Any] { return res }
                    throw CodexRPCError.malformed("missing result field")
                }
            }
        }
        throw CodexRPCError.requestFailed("timeout waiting for response to \(method)")
    }

    private func sendRequest(id: Int, method: String, params: [String: Any]?) throws {
        var payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
        ]
        if let params { payload["params"] = params }
        let data = try JSONSerialization.data(withJSONObject: payload)
        try self.writeLine(data)
    }

    private func sendNotification(method: String, params: [String: Any]? = nil) throws {
        var payload: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method,
        ]
        if let params { payload["params"] = params }
        let data = try JSONSerialization.data(withJSONObject: payload)
        try self.writeLine(data)
    }

    private func writeLine(_ data: Data) throws {
        guard let newline = "\n".data(using: .utf8) else { return }
        let fh = self.stdinPipe.fileHandleForWriting
        try fh.write(contentsOf: data)
        try fh.write(contentsOf: newline)
    }

    private func readNextJSONLine(timeout: TimeInterval) async throws -> [String: Any]? {
        let handle = self.stdoutPipe.fileHandleForReading
        var buf = Data()
        let deadline = Date().addingTimeInterval(min(timeout, 2))
        while Date() < deadline {
            let data = handle.availableData
            if !data.isEmpty { buf.append(data) }
            while let newline = buf.firstIndex(of: 0x0A) { // '\n'
                let line = buf.prefix(upTo: newline)
                buf.removeSubrange(...newline)
                if line.isEmpty { continue }
                if let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any] {
                    return obj
                }
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        return nil
    }

    private static func effectivePATH(baseline: String?) -> String {
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
        var merged = defaults + (baseline?.split(separator: ":").map(String.init) ?? [])
        var seen = Set<String>()
        merged = merged.filter { p in if seen.contains(p) { return false }; seen.insert(p); return true }
        return merged.joined(separator: ":")
    }
}
