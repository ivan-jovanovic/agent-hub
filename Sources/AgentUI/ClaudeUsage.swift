import Foundation
#if canImport(Security)
import Security
#endif

// MARK: - Public Models

enum ClaudeUsageSource: String, CaseIterable {
    case auto = "Auto"
    case oauth = "OAuth"
    case web = "Web"
    case none = "None"
}

struct ClaudeUsageWindow {
    let usedPercent: Double
    let resetsAt: Date?

    var remainingPercent: Double { max(0, 100 - usedPercent) }
}

struct ClaudeUsageSnapshot {
    let primary: ClaudeUsageWindow              // 5h session window
    let weekly: ClaudeUsageWindow?              // 7-day window
    let modelSpecific: ClaudeUsageWindow?       // Opus/Sonnet weekly (if present)
    let providerCost: (used: Double, limit: Double, currency: String)?
    let updatedAt: Date
    let accountEmail: String?
    let accountOrganization: String?
    let loginMethod: String?
}

// MARK: - OAuth Credentials (file-based first)

struct ClaudeOAuthCredentials: Decodable {
    struct Root: Decodable { let claudeAiOauth: OAuth? }
    struct OAuth: Decodable {
        let accessToken: String?
        let refreshToken: String?
        let expiresAt: Double?
        let scopes: [String]?
        let rateLimitTier: String?
    }

    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let scopes: [String]
    let rateLimitTier: String?

    var isExpired: Bool { expiresAt.map { Date() >= $0 } ?? true }

    static func load() throws -> ClaudeOAuthCredentials {
        // 0) Environment override (useful for GUI apps via `launchctl setenv`).
        if let token = ProcessInfo.processInfo.environment["CLAUDE_CODE_OAUTH_TOKEN"], !token.isEmpty {
            return ClaudeOAuthCredentials(
                accessToken: token,
                refreshToken: nil,
                expiresAt: Date().addingTimeInterval(300 * 24 * 60 * 60), // ~10 months
                scopes: ["user:profile"],
                rateLimitTier: nil)
        }

        // 1) Prefer Keychain (if available), then 2) file fallback.
        if let data = try? loadFromKeychain(), let creds = try? parse(data: data) {
            return creds
        }
        let data = try loadFromFile()
        return try parse(data: data)
    }

    static func parse(data: Data) throws -> ClaudeOAuthCredentials {
        let root = try JSONDecoder().decode(Root.self, from: data)
        guard let oauth = root.claudeAiOauth else { throw NSError(domain: "ClaudeOAuth", code: 1) }
        guard let token = oauth.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            throw NSError(domain: "ClaudeOAuth", code: 2)
        }
        let expires = oauth.expiresAt.map { Date(timeIntervalSince1970: $0 / 1000.0) }
        return ClaudeOAuthCredentials(
            accessToken: token,
            refreshToken: oauth.refreshToken,
            expiresAt: expires,
            scopes: oauth.scopes ?? [],
            rateLimitTier: oauth.rateLimitTier)
    }

    static func loadFromFile() throws -> Data {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let url = home.appendingPathComponent(".claude/.credentials.json")
        return try Data(contentsOf: url)
    }

    #if canImport(Security)
    static func loadFromKeychain() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, !data.isEmpty else {
            throw NSError(domain: "ClaudeOAuth", code: Int(status))
        }
        return data
    }
    #else
    static func loadFromKeychain() throws -> Data { throw NSError(domain: "Keychain", code: -1) }
    #endif
}

// MARK: - OAuth Usage Fetcher

enum ClaudeOAuthUsageFetcher {
    struct OAuthUsageResponse: Decodable {
        let fiveHour: Window?
        let sevenDay: Window?
        let sevenDayOpus: Window?
        let sevenDaySonnet: Window?
        let extraUsage: Extra?
        enum CodingKeys: String, CodingKey {
            case fiveHour = "five_hour"
            case sevenDay = "seven_day"
            case sevenDayOpus = "seven_day_opus"
            case sevenDaySonnet = "seven_day_sonnet"
            case extraUsage = "extra_usage"
        }
        struct Window: Decodable { let utilization: Double?; let resetsAt: String?; enum CodingKeys: String, CodingKey { case utilization; case resetsAt = "resets_at" } }
        struct Extra: Decodable { let isEnabled: Bool?; let monthlyLimit: Double?; let usedCredits: Double?; let currency: String?; enum CodingKeys: String, CodingKey { case isEnabled = "is_enabled"; case monthlyLimit = "monthly_limit"; case usedCredits = "used_credits"; case currency } }
    }

    static func fetch(accessToken: String, timeout: TimeInterval = 25) async throws -> OAuthUsageResponse {
        let url = URL(string: "https://api.anthropic.com/api/oauth/usage")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = timeout
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "ClaudeOAuthUsage", code: (resp as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: body])
        }
        return try JSONDecoder().decode(OAuthUsageResponse.self, from: data)
    }
}

// MARK: - Web Cookie Usage Fetcher

enum ClaudeWebUsageFetcher {
    private static let base = "https://claude.ai/api"

    struct Org: Decodable { let uuid: String; let name: String? }
    struct OverageSpend: Decodable {
        let monthlyCreditLimit: Double?
        let currency: String?
        let usedCredits: Double?
        let isEnabled: Bool?
        enum CodingKeys: String, CodingKey {
            case monthlyCreditLimit = "monthly_credit_limit"
            case currency
            case usedCredits = "used_credits"
            case isEnabled = "is_enabled"
        }
    }
    struct AccountResp: Decodable {
        let emailAddress: String?
        let memberships: [Membership]?
        enum CodingKeys: String, CodingKey {
            case emailAddress = "email_address"
            case memberships
        }
        struct Membership: Decodable {
            let organization: Organization
            struct Organization: Decodable {
                let uuid: String?
                let name: String?
                let rateLimitTier: String?
                let billingType: String?
                enum CodingKeys: String, CodingKey {
                    case uuid
                    case name
                    case rateLimitTier = "rate_limit_tier"
                    case billingType = "billing_type"
                }
            }
        }
    }

    static func fetchOrganizations(cookieHeader: String, timeout: TimeInterval = 15) async throws -> [Org] {
        var orgReq = URLRequest(url: URL(string: "\(base)/organizations")!)
        orgReq.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        orgReq.setValue("application/json", forHTTPHeaderField: "Accept")
        orgReq.httpMethod = "GET"
        orgReq.timeoutInterval = timeout
        let (orgData, orgResp) = try await URLSession.shared.data(for: orgReq)
        guard let orgHttp = orgResp as? HTTPURLResponse, orgHttp.statusCode == 200 else {
            throw NSError(domain: "ClaudeWebUsage", code: (orgResp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode([Org].self, from: orgData)
    }

    static func fetch(cookieHeader: String, orgId: String? = nil, timeout: TimeInterval = 20) async throws -> ClaudeUsageSnapshot {
        // 1) Organizations
        let org: Org
        if let orgId {
            org = Org(uuid: orgId, name: nil)
        } else {
            let orgs = try await fetchOrganizations(cookieHeader: cookieHeader, timeout: timeout)
            org = orgs.first ?? Org(uuid: "", name: nil)
        }
        if org.uuid.isEmpty { throw NSError(domain: "ClaudeWebUsage", code: -2) }

        // 2) Usage
        var useReq = URLRequest(url: URL(string: "\(base)/organizations/\(org.uuid)/usage")!)
        useReq.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        useReq.setValue("application/json", forHTTPHeaderField: "Accept")
        useReq.httpMethod = "GET"
        useReq.timeoutInterval = timeout
        let (useData, useResp) = try await URLSession.shared.data(for: useReq)
        guard let useHttp = useResp as? HTTPURLResponse, useHttp.statusCode == 200 else {
            throw NSError(domain: "ClaudeWebUsage", code: (useResp as? HTTPURLResponse)?.statusCode ?? -1)
        }

        guard let json = try? JSONSerialization.jsonObject(with: useData) as? [String: Any] else {
            throw NSError(domain: "ClaudeWebUsage", code: -3)
        }
        func iso(_ s: String?) -> Date? {
            guard let s, !s.isEmpty else { return nil }
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f.date(from: s) ?? { f.formatOptions = [.withInternetDateTime]; return f.date(from: s) }()
        }

        var session: ClaudeUsageWindow?
        if let five = json["five_hour"] as? [String: Any] {
            let pct = (five["utilization"] as? NSNumber)?.doubleValue ?? 0
            let resets = iso(five["resets_at"] as? String)
            session = ClaudeUsageWindow(usedPercent: pct, resetsAt: resets)
        }
        guard let primary = session else { throw NSError(domain: "ClaudeWebUsage", code: -4) }

        var weekly: ClaudeUsageWindow?
        if let sev = json["seven_day"] as? [String: Any] {
            let pct = (sev["utilization"] as? NSNumber)?.doubleValue ?? 0
            let resets = iso(sev["resets_at"] as? String)
            weekly = ClaudeUsageWindow(usedPercent: pct, resetsAt: resets)
        } else if let sevApps = json["seven_day_oauth_apps"] as? [String: Any] {
            let pct = (sevApps["utilization"] as? NSNumber)?.doubleValue ?? 0
            let resets = iso(sevApps["resets_at"] as? String)
            weekly = ClaudeUsageWindow(usedPercent: pct, resetsAt: resets)
        }

        var model: ClaudeUsageWindow?
        if let op = json["seven_day_opus"] as? [String: Any] {
            let pct = (op["utilization"] as? NSNumber)?.doubleValue ?? 0
            let resets = iso(op["resets_at"] as? String)
            model = ClaudeUsageWindow(usedPercent: pct, resetsAt: resets)
        } else if let son = json["seven_day_sonnet"] as? [String: Any] {
            let pct = (son["utilization"] as? NSNumber)?.doubleValue ?? 0
            let resets = iso(son["resets_at"] as? String)
            model = ClaudeUsageWindow(usedPercent: pct, resetsAt: resets)
        }

        // Optional: extra usage cost
        var cost: (used: Double, limit: Double, currency: String)?
        do {
            var overReq = URLRequest(url: URL(string: "\(base)/organizations/\(org.uuid)/overage_spend_limit")!)
            overReq.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            overReq.setValue("application/json", forHTTPHeaderField: "Accept")
            overReq.httpMethod = "GET"
            overReq.timeoutInterval = timeout
            let (overData, overResp) = try await URLSession.shared.data(for: overReq)
            if let http = overResp as? HTTPURLResponse, http.statusCode == 200 {
                if let decoded = try? JSONDecoder().decode(OverageSpend.self, from: overData), decoded.isEnabled == true,
                   let used = decoded.usedCredits, let limit = decoded.monthlyCreditLimit
                {
                    let currency = (decoded.currency?.isEmpty ?? true) ? "USD" : decoded.currency!
                    cost = (used: used / 100.0, limit: limit / 100.0, currency: currency)
                }
            }
        } catch { /* ignore extras */ }

        // Optional: account email/plan
        var accountEmail: String? = nil
        var loginMethod: String? = nil
        do {
            var acctReq = URLRequest(url: URL(string: "\(base)/account")!)
            acctReq.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            acctReq.setValue("application/json", forHTTPHeaderField: "Accept")
            acctReq.httpMethod = "GET"
            acctReq.timeoutInterval = timeout
            let (acctData, acctResp) = try await URLSession.shared.data(for: acctReq)
            if let http = acctResp as? HTTPURLResponse, http.statusCode == 200, let acc = try? JSONDecoder().decode(AccountResp.self, from: acctData) {
                accountEmail = acc.emailAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
                // Derive a friendly plan name
                let tier = acc.memberships?.first?.organization.rateLimitTier?.lowercased() ?? ""
                if tier.contains("max") { loginMethod = "Claude Max" }
                else if tier.contains("pro") { loginMethod = "Claude Pro" }
                else if tier.contains("team") { loginMethod = "Claude Team" }
                else if tier.contains("enterprise") { loginMethod = "Claude Enterprise" }
            }
        } catch { /* ignore */ }

        return ClaudeUsageSnapshot(
            primary: primary,
            weekly: weekly,
            modelSpecific: model,
            providerCost: cost,
            updatedAt: Date(),
            accountEmail: accountEmail,
            accountOrganization: org.name,
            loginMethod: loginMethod)
    }
}
