import Foundation
import SwiftUI

@MainActor
final class UsageService: ObservableObject {
    @Published var usage: ClaudeUsageSnapshot?
    @Published var isLoading = false
    @Published var error: String?
    @Published var organizations: [(id: String, name: String?)] = []

    @AppStorage("usageSource") var sourceString: String = ClaudeUsageSource.auto.rawValue
    @AppStorage("usageSessionKey") var sessionKey: String = ""
    @AppStorage("usageOrgId") var orgId: String = ""

    var source: ClaudeUsageSource {
        ClaudeUsageSource(rawValue: sourceString) ?? .auto
    }

    func refresh() {
        error = nil
        isLoading = true
        usage = nil

        Task.detached { [sourceString, sessionKey, orgId] in
            let chosen = ClaudeUsageSource(rawValue: sourceString) ?? .auto
            do {
                if let snap = try await Self.loadUsage(source: chosen, sessionKey: sessionKey, orgId: orgId.isEmpty ? nil : orgId) {
                    await MainActor.run {
                        self.usage = snap
                        self.isLoading = false
                    }
                    return
                }
                await MainActor.run {
                    self.error = "No usage available (check settings)"
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private static func loadUsage(source: ClaudeUsageSource, sessionKey: String, orgId: String?) async throws -> ClaudeUsageSnapshot? {
        enum UsageLoadError: LocalizedError {
            case noOAuthCredentials
            case expiredOAuthToken
            case missingScope

            var errorDescription: String? {
                switch self {
                case .noOAuthCredentials: return "No Claude OAuth credentials found (set CLAUDE_CODE_OAUTH_TOKEN or run 'claude' to sign in)."
                case .expiredOAuthToken: return "Claude OAuth token is expired. Run 'claude' to refresh."
                case .missingScope: return "Claude OAuth token missing 'user:profile' scope (required for usage)."
                }
            }
        }

        func oauthFetch() async throws -> ClaudeUsageSnapshot? {
            let creds: ClaudeOAuthCredentials
            do {
                creds = try ClaudeOAuthCredentials.load()
            } catch {
                throw UsageLoadError.noOAuthCredentials
            }
            if creds.isExpired { throw UsageLoadError.expiredOAuthToken }
            if !creds.scopes.contains("user:profile") {
                throw UsageLoadError.missingScope
            }

            let resp = try await ClaudeOAuthUsageFetcher.fetch(accessToken: creds.accessToken)
            func mk(_ w: ClaudeOAuthUsageFetcher.OAuthUsageResponse.Window?) -> ClaudeUsageWindow? {
                guard let w, let pct = w.utilization else { return nil }
                let date = ClaudeOAuthUsageFetcher.parseISO8601Date(w.resetsAt)
                return ClaudeUsageWindow(usedPercent: pct, resetsAt: date)
            }
            guard let primary = mk(resp.fiveHour) else { return nil }
            let weekly = mk(resp.sevenDay)
            let model = mk(resp.sevenDaySonnet ?? resp.sevenDayOpus)
            var providerCost: (Double, Double, String)?
            if let extra = resp.extraUsage, extra.isEnabled == true,
               let used = extra.usedCredits, let limit = extra.monthlyLimit
            {
                // Amounts are cents → USD
                providerCost = (used / 100.0, limit / 100.0, (extra.currency ?? "USD"))
            }
            return ClaudeUsageSnapshot(
                primary: primary,
                weekly: weekly,
                modelSpecific: model,
                providerCost: providerCost.map { (used: $0.0, limit: $0.1, currency: $0.2) },
                updatedAt: Date(),
                accountEmail: nil,
                accountOrganization: nil,
                loginMethod: creds.rateLimitTier)
        }

        func webFetch(using key: String) async throws -> ClaudeUsageSnapshot? {
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let header = trimmed.hasPrefix("sessionKey=") ? trimmed : "sessionKey=\(trimmed)"
            return try await ClaudeWebUsageFetcher.fetch(cookieHeader: header, orgId: orgId)
        }

        switch source {
        case .oauth:
            return try await oauthFetch()
        case .web:
            return try await webFetch(using: sessionKey)
        case .auto:
            if let o = try await oauthFetch() { return o }
            if let w = try await webFetch(using: sessionKey) { return w }
            return nil
        case .none:
            return nil
        }
    }

    func loadOrganizations() {
        let trimmed = sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let header = trimmed.hasPrefix("sessionKey=") ? trimmed : "sessionKey=\(trimmed)"
        Task.detached {
            do {
                let orgs = try await ClaudeWebUsageFetcher.fetchOrganizations(cookieHeader: header)
                let mapped = orgs.map { ($0.uuid, $0.name) }
                await MainActor.run {
                    self.organizations = mapped
                }
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }
}

extension ClaudeOAuthUsageFetcher {
    static func parseISO8601Date(_ string: String?) -> Date? {
        guard let s = string, !s.isEmpty else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}
