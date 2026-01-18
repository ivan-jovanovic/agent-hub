import Foundation
import SwiftUI

@MainActor
final class CodexUsageService: ObservableObject {
    @Published var usage: CodexUsageSnapshot?
    @Published var isLoading = false
    @Published var error: String?

    func refresh() {
        error = nil
        isLoading = true
        usage = nil

        Task.detached {
            do {
                let snap = try await CodexStatusProbe.fetch()
                await MainActor.run {
                    self.usage = snap
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
}

