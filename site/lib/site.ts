import { readFileSync } from "node:fs";
import { join } from "node:path";

export const SITE_URL = "https://flightdeck.pladsen.dev";
export const REPOSITORY_URL = "https://github.com/MagnusPladsen/flightdeck";
export const RELEASES_URL = `${REPOSITORY_URL}/releases`;
export const DOWNLOAD_URL = `${RELEASES_URL}/latest/download/Flightdeck.zip`;
export const TAP_URL = "https://github.com/MagnusPladsen/homebrew-tap";

export const BREW_COMMANDS = [
  "brew trust magnuspladsen/tap",
  "brew install --cask magnuspladsen/tap/flightdeck",
];

/** The app version from the repo's VERSION file, read at build time. */
export function getAppVersion(): string | null {
  try {
    return readFileSync(join(process.cwd(), "..", "VERSION"), "utf8").trim();
  } catch {
    return null;
  }
}
