import { readFileSync } from "node:fs";
import { join } from "node:path";

export const SITE_URL = "https://flightdeck.pladsen.dev";
export const REPOSITORY_URL = "https://github.com/MagnusPladsen/flightdeck";
export const RELEASES_URL = `${REPOSITORY_URL}/releases`;
export const DOWNLOAD_URL = `${RELEASES_URL}/latest/download/Flightdeck.zip`;
export const CHANGELOG_URL = `${REPOSITORY_URL}/blob/main/CHANGELOG.md`;
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

export type ChangelogEntry = { version: string; date: string; items: string[] };

/** The releases in the repo's CHANGELOG.md, newest first, read at build time. */
export function getChangelog(): ChangelogEntry[] {
  let markdown: string;
  try {
    markdown = readFileSync(join(process.cwd(), "..", "CHANGELOG.md"), "utf8");
  } catch {
    return [];
  }
  const entries: ChangelogEntry[] = [];
  for (const line of markdown.split("\n").map((text) => text.trim())) {
    if (line.startsWith("## ")) {
      const [version, date = ""] = line.slice(3).split("—").map((part) => part.trim());
      entries.push({ version, date, items: [] });
    } else if (line.startsWith("- ") && entries.length > 0) {
      entries[entries.length - 1].items.push(line.slice(2));
    }
  }
  return entries;
}
