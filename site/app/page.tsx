import Image from "next/image";
import { AgentBoard } from "@/components/AgentBoard";
import { Clock } from "@/components/Clock";
import { CopyCommand } from "@/components/CopyCommand";
import { FormationMark } from "@/components/FormationMark";
import { NeedsYouHeadline } from "@/components/NeedsYouHeadline";
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

const FEATURES = [
  {
    title: "AI agents",
    body: "Which folders Claude Code, Codex and other agents are working in, and whether each is working, waiting for approval or waiting for you.",
  },
  {
    title: "Needs you",
    body: "The agent waiting on you leads the overview. Reply opens its terminal; hover a card and clear it until that agent does something new.",
  },
  {
    title: "Dev servers",
    body: "Every listening port mapped to its git project, branch and worktree, with the framework detected. Open it in the browser, editor or terminal, or stop it.",
  },
  {
    title: "Ask Claude",
    body: "Press ⌘K and ask about your agents, ports and usage. The answer opens in a palette, and agents it names open their terminal in one click.",
  },
  {
    title: "System and limits",
    body: "CPU, memory, network and disk with live sparklines, plus Codex and Claude usage limits read from local logs.",
  },
  {
    title: "Your layout",
    body: "13 themes, each with its own layout. Unlock any page to drag, resize or hide sections on a 12-column grid.",
  },
];

const SCREENS = [
  { src: "/screenshots/agents.png", alt: "AI agents page with usage limits", caption: "Agents and usage limits", width: 1180, height: 917 },
  { src: "/screenshots/ports.png", alt: "Servers and ports page grouped by project", caption: "Dev servers by project", width: 1180, height: 780 },
  { src: "/screenshots/edit-layout.png", alt: "Layout editing with the page unlocked", caption: "Rearrange any page", width: 1180, height: 917 },
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
          <a href="#features">Features</a>
          <a href="#screens">Screens</a>
          <a href="#changelog">Changelog</a>
          <a href="#install">Install</a>
          <a href={REPOSITORY_URL}>GitHub</a>
        </nav>
      </header>

      <main id="top">
        <section className="hero">
          <p className="eyebrow reveal">
            <span className="pulse" /> Agent and system monitor for developers
            {version && <span className="version">v{version}</span>}
          </p>
          <div className="hero-row reveal" style={{ animationDelay: "80ms" }}>
            <NeedsYouHeadline />
            <Clock />
          </div>
          <div className="hero-foot reveal" style={{ animationDelay: "160ms" }}>
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
          </div>
          <p className="platforms reveal" style={{ animationDelay: "240ms" }}>
            <span>macOS 14+</span>
            <span>Apple Silicon and Intel</span>
            <span>Free and open source</span>
            <span className="is-later">Linux coming later</span>
          </p>
        </section>

        <section className="showcase reveal" style={{ animationDelay: "320ms" }}>
          <div className="glow" aria-hidden="true" />
          <Image
            className="shot shot-main"
            src="/screenshots/overview.png"
            alt="Flightdeck overview: the agent that needs you, a big clock, resources and agents"
            width={1146}
            height={1135}
            priority
          />
          <Image
            className="shot shot-panel"
            src="/screenshots/menu-bar-panel.png"
            alt="Flightdeck menu bar panel"
            width={380}
            height={739}
          />
        </section>

        <section className="board-section">
          <div className="section-title">
            <span className="index">01</span>
            <h2>
              Every agent, one glance.
              <br />
              <span className="muted">The one waiting on you goes first.</span>
            </h2>
          </div>
          <AgentBoard />
        </section>

        <section id="features" className="features">
          <div className="section-title">
            <span className="index">02</span>
            <h2>What&apos;s on deck.</h2>
          </div>
          <ol className="feature-list">
            {FEATURES.map((feature, index) => (
              <li key={feature.title}>
                <span className="feature-number">{String(index + 1).padStart(2, "0")}</span>
                <h3>{feature.title}</h3>
                <p>{feature.body}</p>
              </li>
            ))}
          </ol>
        </section>

        <section id="screens" className="screens">
          <div className="section-title">
            <span className="index">03</span>
            <h2>Near-black, loud where it matters.</h2>
          </div>
          <div className="screen-grid">
            {SCREENS.map((screen) => (
              <figure key={screen.src}>
                <Image src={screen.src} alt={screen.alt} width={screen.width} height={screen.height} />
                <figcaption>{screen.caption}</figcaption>
              </figure>
            ))}
          </div>
        </section>

        {releases.length > 0 && (
          <section id="changelog" className="changelog">
            <div className="section-title">
              <span className="index">04</span>
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
              <span className="index">05</span>
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
