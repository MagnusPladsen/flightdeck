import Image from "next/image";
import { CopyCommand } from "@/components/CopyCommand";
import { FormationMark } from "@/components/FormationMark";
import {
  BREW_COMMANDS,
  CHANGELOG_URL,
  DOWNLOAD_URL,
  RELEASES_URL,
  REPOSITORY_URL,
  TAP_URL,
  getAppVersion,
  getChangelog,
} from "@/lib/site";

/** Numbered labels on the overview screenshot, positioned in % of the image. */
const PINS = [
  {
    x: 22,
    y: 8.5,
    title: "Search and ask",
    body: "Type to find any agent or project across Claude Code, Codex, Gemini CLI, Cursor Agent, opencode and Aider. Press Return or ⌘K to ask Claude about what's running. The picker sets your default agent, whose limits show below.",
  },
  { x: 22, y: 20, title: "Who needs you", body: "The agent waiting on you leads, with a count of the others." },
  {
    x: 22,
    y: 44.5,
    title: "Go to terminal",
    body: "Focuses that agent's own Ghostty, iTerm2, Terminal or tmux tab. Later sets it aside, Stop interrupts it. ⌃⌥N jumps to the next agent that needs you from any app.",
  },
  { x: 73, y: 23, title: "A big clock", body: "Readable from across the room on a second screen." },
  {
    x: 22,
    y: 58.5,
    title: "System and limits",
    body: "CPU and memory, plus your default agent's 5h and week limits. Add disk, network, battery or Claude Code and Codex limits side by side.",
  },
  {
    x: 22,
    y: 68,
    title: "Now playing",
    body: "What's playing in any player, with previous, play/pause, next and a volume slider for Spotify and Music. Collapse it, or System, when you need the room.",
  },
  {
    x: 22,
    y: 86.5,
    title: "Needs you",
    body: "Every waiting agent: what it said or wants to run, its folder, branch, CPU and memory. Agents that look stuck get a badge with the reason. Hover a card and clear it until that agent does something new. Each card shows what the agent changed since it started, with a Diff button, and which step of its task list Claude is on.",
  },
  {
    x: 10,
    y: 40,
    title: "Pages",
    body: "Servers and ports, AI agents, worktrees, processes and widgets. The Office and Settings sit at the bottom of the sidebar.",
  },
];

const FEATURE_ROWS = [
  {
    label: "AI agents",
    title: "Every agent, one glance.",
    body: "Which folders Claude Code, Codex, Gemini CLI, Cursor Agent, opencode and Aider are working in, and whether each is working, waiting for approval, waiting for you or looks stuck. Go to terminal or stop any of them from its row. Token spend per project and model is there too if you turn it on. Cards show which step of its task list each agent is on and the files and lines it changed, with a diff one click away, and New agent starts Claude Code or Codex in a fresh worktree. Limits come with a forecast of when they run out, and Today sums up agent time and time spent waiting on you.",
    image: { src: "/screenshots/agents.png", alt: "AI agents page with usage limits", width: 1194, height: 1085 },
  },
  {
    label: "Office",
    title: "Walk around your agents.",
    body: "A pixel-art office with a room per repo, where every agent is posed by what it's doing. Agents that need you wait as bouncing avatars along the top, and a jukebox plays what's on. When music plays it turns into a party in your visualiser colours, with a flashing dance floor, lasers, pumping speakers and every agent nodding to the beat. Click the pads in front of the jukebox to skip or pause. Walk up to an agent to go to its terminal or stop it.",
    image: { src: "/screenshots/office.png", alt: "Office party with a dance floor, lasers, speaker stacks and the jukebox pads", width: 1194, height: 760 },
  },
  {
    label: "Now playing",
    title: "Music in your theme.",
    body: "What's playing in any player, with a visualiser in your theme's colours. The adjust menu switches between Minimal and Expanded, five visualiser styles and six palettes. Live audio levels are opt-in; otherwise the bars follow play and pause.",
    image: { src: "/screenshots/now-playing.png", alt: "Now playing with player controls and the adjust menu open", width: 1024, height: 362 },
  },
  {
    label: "Worktrees",
    title: "Clear out old worktrees.",
    body: "Every git worktree with its changes, ahead/behind, PR and the agent working in it. Clean ones with no agent, no open PR and no recent commits are marked stale, and one click cleans them up. Open pull requests show CI and review status, and you get an alert when CI fails on a branch an agent is working in.",
    image: { src: "/screenshots/worktrees.png", alt: "Worktrees page with stale worktrees and Clean up", width: 1194, height: 1085 },
  },
  {
    label: "Dev servers",
    title: "Know what's on :3000.",
    body: "Every listening port mapped to its git project, branch and worktree, with the framework detected. Open it in the browser, editor or terminal, or stop it. Stopped servers stay listed with Run again, port conflicts are flagged, and Restart reruns a server in a terminal tab.",
    image: { src: "/screenshots/ports.png", alt: "Servers and ports page grouped by project", width: 1194, height: 1085 },
  },
  {
    label: "Menu bar",
    title: "One click away.",
    body: "The panel shows who needs you, CPU and memory, and your dev servers, without opening the dashboard. Its bell pauses alerts for a while.",
    image: { src: "/screenshots/menu-bar-panel.png", alt: "Flightdeck menu bar panel", width: 380, height: 740 },
    isPanel: true,
  },
  {
    label: "Settings",
    title: "Settings, in the dashboard.",
    body: "Settings is a page in the dashboard, not a separate window. Set quiet hours, and alerts held back arrive as one summary afterwards. Change the next-agent shortcut, or turn on token spend with a daily budget alert. Alerts can follow macOS Focus, Keep awake stops the Mac sleeping while agents work, and the flightdeck command feeds SketchyBar and tmux.",
    image: { src: "/screenshots/settings.png", alt: "Settings page in the dashboard", width: 1180, height: 917 },
  },
  {
    label: "Your layout",
    title: "Rearrange any page.",
    body: "13 layouts and 22 themes. Copy a built-in theme to make your own colours. Unlock any page to drag, resize or hide sections on a 12-column grid.",
    image: { src: "/screenshots/edit-layout.png", alt: "Layout editing with the page unlocked", width: 1180, height: 917 },
  },
];

const CHANGELOG_LIMIT = 4;

export default function Home() {
  const version = getAppVersion();
  const releases = getChangelog().slice(0, CHANGELOG_LIMIT);

  return (
    <>
      <div className="grain" aria-hidden="true" />
      <header className="nav">
        <a href="#top" className="brand">
          <FormationMark size={26} />
          Flightdeck
        </a>
        <nav>
          <a href="#tour">Tour</a>
          <a href="#features">Features</a>
          <a href="#changelog">Changelog</a>
          <a href="#install">Install</a>
          <a href={REPOSITORY_URL}>GitHub</a>
        </nav>
      </header>

      <main id="top">
        <section className="hero">
          <div className="hero-copy reveal">
            <p className="eyebrow">
              <span className="pulse" /> Agent and system monitor for macOS
              {version && <span className="version">v{version}</span>}
            </p>
            <h1 className="headline">
              Every agent you run,
              <br />
              <span className="accent">on one screen.</span>
            </h1>
          </div>
          <div className="hero-side reveal" style={{ animationDelay: "120ms" }}>
            <p className="lede">
              Flightdeck lives in the macOS menu bar and tells you which AI agents are working, which are waiting on you and
              where, next to your dev servers and system resources.
            </p>
            <div className="cta">
              <a className="button is-primary" href={DOWNLOAD_URL}>
                Download for macOS
              </a>
              <a className="button" href="#install">
                Install with Homebrew
              </a>
            </div>
            <p className="platforms">
              <span>macOS 14+</span>
              <span>Apple Silicon and Intel</span>
              <span>Free and open source</span>
            </p>
          </div>
        </section>

        <section id="tour" className="tour reveal" style={{ animationDelay: "240ms" }}>
          <div className="tour-shot">
            <Image
              className="shot"
              src="/screenshots/overview.png"
              alt="Flightdeck overview with numbered labels: search and ask, who needs you, go to terminal, clock, system and limits, now playing, the Needs you list and pages"
              width={1194}
              height={1085}
              priority
            />
            {PINS.map((pin, index) => (
              <span key={pin.title} className="pin" style={{ left: `${pin.x}%`, top: `${pin.y}%` }} aria-hidden="true">
                {index + 1}
              </span>
            ))}
          </div>
          <ol className="pin-list">
            {PINS.map((pin, index) => (
              <li key={pin.title}>
                <span className="pin-key">{index + 1}</span>
                <div>
                  <strong>{pin.title}</strong>
                  <span>{pin.body}</span>
                </div>
              </li>
            ))}
          </ol>
        </section>

        <section id="features" className="features">
          {FEATURE_ROWS.map((row, index) => (
            <div key={row.label} className={index % 2 === 1 ? "feature-row is-flipped" : "feature-row"}>
              <div className={row.isPanel ? "feature-shot is-panel" : "feature-shot"}>
                <Image className="shot" src={row.image.src} alt={row.image.alt} width={row.image.width} height={row.image.height} />
              </div>
              <div className="feature-copy">
                <span className="index">{row.label}</span>
                <h2>{row.title}</h2>
                <p>{row.body}</p>
              </div>
            </div>
          ))}
        </section>

        {releases.length > 0 && (
          <section id="changelog" className="changelog">
            <div className="section-title">
              <h2>Flight log.</h2>
            </div>
            <ol className="release-list">
              {releases.map((release) => (
                <li key={release.version}>
                  <div className="release-head">
                    <strong>v{release.version}</strong>
                    <span>{release.date}</span>
                  </div>
                  <ul>
                    {release.items.map((item) => (
                      <li key={item}>{item}</li>
                    ))}
                  </ul>
                </li>
              ))}
            </ol>
            <a className="changelog-link" href={CHANGELOG_URL}>
              Full changelog →
            </a>
          </section>
        )}

        <section id="install" className="install">
          <div className="install-inner">
            <div className="section-title">
              <h2>Cleared for takeoff.</h2>
            </div>
            <div className="install-grid">
              <div className="install-card">
                <h3>Homebrew</h3>
                {BREW_COMMANDS.map((command) => (
                  <CopyCommand key={command} command={command} />
                ))}
                <p>
                  Newer Homebrew versions only load casks from taps you trust, hence the first line. The cask lives in{" "}
                  <a href={TAP_URL}>magnuspladsen/homebrew-tap</a>.
                </p>
              </div>
              <div className="install-card">
                <h3>Download</h3>
                <a className="button is-dark" href={DOWNLOAD_URL}>
                  Flightdeck.zip{version && ` · v${version}`}
                </a>
                <p>
                  Unzip and move it to Applications. It isn&apos;t notarized yet: if macOS blocks it, allow it under System
                  Settings › Privacy &amp; Security › Open Anyway.
                </p>
                <p>It updates itself with Sparkle. Older builds are on the <a href={RELEASES_URL}>releases page</a>.</p>
              </div>
            </div>
            <div className="platform-strip">
              <div>
                <strong>macOS</strong>
                <span>Available now · macOS 14 Sonoma or later</span>
              </div>
              <div className="is-later">
                <strong>Linux</strong>
                <span>Coming later · the core library already builds there</span>
              </div>
            </div>
          </div>
        </section>
      </main>

      <footer className="footer">
        <a href="#top" className="brand">
          <FormationMark size={22} />
          Flightdeck
        </a>
        <span>
          Made by <a href="https://github.com/MagnusPladsen">Magnus Pladsen</a> · <a href={REPOSITORY_URL}>Source on GitHub</a> · MIT License
        </span>
      </footer>
    </>
  );
}
