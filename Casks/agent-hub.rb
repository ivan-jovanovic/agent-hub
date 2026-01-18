cask "agent-hub" do
  version "1.0.0"
  sha256 :no_check # Updated automatically on release

  url "https://github.com/ivan-jovanovic/agent-hub/releases/download/v#{version}/Agent-Hub-v#{version}.zip"
  name "Agent Hub"
  desc "Menu bar app for managing Claude Code and Codex CLI sessions"
  homepage "https://github.com/ivan-jovanovic/agent-hub"

  depends_on macos: ">= :sonoma"

  app "Agent Hub.app"

  zap trash: [
    "~/Library/Preferences/com.personal.AgentHub.plist",
    "~/Library/Application Support/Agent Hub",
  ]
end
