cask "system-monitor" do
  version "1.0.0"
  sha256 "filled-in-by-the-release-workflow"

  url "https://github.com/MagnusPladsen/system-monitor/releases/download/v#{version}/SystemMonitor.zip"
  name "System Monitor"
  desc "Menu bar system monitor for developers: dev servers, AI agents and usage limits"
  homepage "https://github.com/MagnusPladsen/system-monitor"

  depends_on macos: :sonoma

  app "SystemMonitor.app"

  uninstall quit: "com.magnuspladsen.SystemMonitor"

  zap trash: "~/Library/Preferences/com.magnuspladsen.SystemMonitor.plist"

  caveats <<~EOS
    System Monitor is not notarized by Apple yet. If macOS refuses to open it, run:

      xattr -dr com.apple.quarantine "#{appdir}/SystemMonitor.app"

    or allow it under System Settings → Privacy & Security → Open Anyway.
  EOS
end
