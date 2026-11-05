cask "flightdeck" do
  version "1.0.0"
  sha256 "filled-in-by-the-release-workflow"

  url "https://github.com/MagnusPladsen/flightdeck/releases/download/v#{version}/Flightdeck.zip"
  name "Flightdeck"
  desc "Agent and system monitor for developers, in the menu bar"
  homepage "https://flightdeck.pladsen.dev"

  # GitHub's release list skips pre-releases; the app's own update feed does not
  livecheck do
    url "https://github.com/MagnusPladsen/flightdeck/releases/download/update-feed/appcast.xml"
    strategy :sparkle, &:short_version
  end

  auto_updates true
  depends_on macos: :sonoma

  app "Flightdeck.app"

  uninstall quit: "com.magnuspladsen.Flightdeck"

  zap trash: "~/Library/Preferences/com.magnuspladsen.Flightdeck.plist"

  caveats <<~EOS
    Flightdeck is not notarized by Apple yet. If macOS refuses to open it, run:

      xattr -dr com.apple.quarantine "#{appdir}/Flightdeck.app"

    or allow it under System Settings → Privacy & Security → Open Anyway.
  EOS
end
