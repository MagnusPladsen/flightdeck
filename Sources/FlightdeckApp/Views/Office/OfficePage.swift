import MonitorCore
import SwiftUI

/// The walkable office: one room per project, built from the live agents, servers and system readings.
struct OfficePage: View {
    @Environment(MonitorStore.self) private var store

    var body: some View {
        OfficeStage(map: OfficeMap.build(agents: store.agents, ports: store.devServers), readings: readings)
    }

    private var readings: OfficeReadings {
        let limits = store.usage(for: store.limitsAgent)
        return OfficeReadings(agents: store.agents, snapshot: store.snapshot, limitsTool: store.limitsAgent, limitWindows: limits?.windows ?? [],
                              track: store.nowPlaying.isVisible ? store.nowPlaying.track : nil)
    }
}

/// The live numbers the office's objects show.
struct OfficeReadings {
    var agents: [AgentSession]
    var snapshot: SystemSnapshot?
    var limitsTool: AgentTool
    var limitWindows: [UsageWindow]
    /// What the Mac is playing, while the Now playing section would show it.
    var track: NowPlayingTrack?

    var limitsHeadroom: Double? {
        limitWindows.map(\.usedPercent).max().map { 1 - $0 / 100 }
    }
}

private struct OfficeStage: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let map: OfficeMap
    let readings: OfficeReadings
    @State private var game = OfficeGame()
    @State private var hovered: OfficeObject?
    @State private var pointer: CGPoint = .zero
    @State private var needsYou = NeedsYouQueue()
    @State private var party = OfficePartyFeed()
    @State private var pressedPad: (command: NowPlayingCommand, at: Date)?
    @Namespace private var avatarSpace
    @FocusState private var isFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            let camera = OfficeCamera(mapWidth: map.grid.width, mapHeight: map.grid.height, viewWidth: geometry.size.width,
                                      viewHeight: geometry.size.height, focus: game.player)
            ZStack(alignment: .topLeading) {
                canvas(camera: camera)
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { click(at: $0, camera: camera) }
                    .onContinuousHover(coordinateSpace: .local) { hover($0, camera: camera) }
                agentCard(camera: camera, size: geometry.size)
                tooltip(size: geometry.size)
                needsYouCorner.padding(12)
                hint.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).padding(12)
            }
        }
        .background(theme.background)
        .background { if store.settings.officePartyEnabled { OfficeAudioListener() } }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(phases: .all, action: handleKey)
        .defaultFocus($isFocused, true)
        .onAppear { Task { isFocused = true } }
        .onChange(of: isFocused) { _, focused in if !focused { game.releaseAll() } }
        .onChange(of: map, initial: true) { _, newMap in game.update(map: newMap) }
        .onChange(of: waitingPIDs, initial: true) { needsYou.update(agents: readings.agents, now: .now) }
        .task { await runLoop() }
    }

    private func canvas(camera: OfficeCamera) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            let party = partyFrame(at: timeline.date)
            let outside = outside(at: timeline.date)
            Canvas { context, size in
                let scene = scene(party: party, outside: outside)
                OfficeRenderer(scene: scene, pen: OfficePen(context: context, camera: camera), time: timeline.date.timeIntervalSinceReferenceDate).draw(size: size)
            }
        }
    }

    private func partyFrame(at date: Date) -> OfficeParty? {
        guard store.settings.officePartyEnabled, let track = readings.track, track.isPlaying else { return nil }
        return party.frame(at: date, track: track, audio: store.nowPlaying.audio, colors: partyColors, allowsStrobe: !reduceMotion)
    }

    private var partyColors: [Color] {
        store.visualizerColors(theme: theme).stops
    }

    /// Nil keeps the office at noon, when the time of day is turned off.
    private func outside(at date: Date) -> OfficeOutside? {
        if let pinned = OfficeOutside.demoOverride { return pinned }
        guard store.settings.officeFollowsTimeOfDay else { return nil }
        let weather = store.officeWeather
        let usesWeather = store.settings.officeWeatherEnabled && weather.placeName != nil
        return .at(date, sunrise: usesWeather ? weather.sunrise : nil, sunset: usesWeather ? weather.sunset : nil,
                   condition: usesWeather ? weather.condition : .clear)
    }

    private func scene(party: OfficeParty?, outside: OfficeOutside?) -> OfficeScene {
        let spotlight: Int32? = if case .agent(let pid) = hovered { pid } else { game.cardPID }
        return OfficeScene(map: game.map, agents: Dictionary(readings.agents.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first }),
                           cpuLoad: readings.snapshot?.cpu.total ?? 0, memory: readings.snapshot?.memory, limitsHeadroom: readings.limitsHeadroom,
                           isMusicPlaying: readings.track?.isPlaying == true, track: readings.track, party: party,
                           isAtJukebox: isAtJukebox, pressedPad: recentlyPressedPad,
                           player: game.player, isPlayerWalking: game.isWalking, playerFacesLeft: game.facesLeft, spotlightPID: spotlight,
                           outside: outside)
    }

    /// Steps the player about sixty times a second while the page is on screen, and counts the
    /// tiles walked and the party minutes for the achievements every few seconds.
    private func runLoop() async {
        store.achievements.record(.officeVisits)
        var last = Date()
        var lastFlush = last
        var walked = 0.0, partySeconds = 0.0
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(16))
            let now = Date()
            let seconds = min(0.05, now.timeIntervalSince(last))
            let before = game.player
            game.tick(seconds: seconds)
            walked += game.player.distance(to: before)
            if partyFrame(at: now) != nil { partySeconds += seconds }
            last = now
            guard now.timeIntervalSince(lastFlush) >= 5 else { continue }
            store.achievements.record(.officeTilesWalked, by: walked)
            store.achievements.record(.partyMinutes, by: partySeconds / 60)
            (walked, partySeconds, lastFlush) = (0, 0, now)
        }
    }

    private func click(at location: CGPoint, camera: OfficeCamera) {
        isFocused = true
        let point = camera.officePoint(screenX: location.x, screenY: location.y)
        switch map.object(at: point) {
        case .agent(let pid): game.select(pid)
        case .rack(let port): store.openInBrowser(port: port.port)
        case .jukeboxPad(let command) where readings.track != nil: pressPad(command)
        default: game.walk(to: point.tile)
        }
    }

    private func hover(_ phase: HoverPhase, camera: OfficeCamera) {
        switch phase {
        case .active(let location):
            pointer = location
            hovered = map.object(at: camera.officePoint(screenX: location.x, screenY: location.y))
        case .ended:
            hovered = nil
        }
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        if let direction = Self.direction(for: press) {
            if press.phase == .up { game.release(direction) } else { game.press(direction) }
            return .handled
        }
        guard press.phase == .down else { return .ignored }
        switch press.key {
        case .space, .return:
            if let agent = cardAgent {
                store.openTerminal(for: agent)
            } else if isAtJukebox {
                pressPad(.togglePlayPause)
            } else {
                return .ignored
            }
            return .handled
        case .escape:
            game.closeCard()
            return .handled
        default:
            return handleJukeboxKey(press.characters.lowercased())
        }
    }

    private func handleJukeboxKey(_ characters: String) -> KeyPress.Result {
        guard isAtJukebox else { return .ignored }
        switch characters {
        case "q": pressPad(.previousTrack)
        case "e": pressPad(.nextTrack)
        default: return .ignored
        }
        return .handled
    }

    /// The player stands by the jukebox while something is playing or just paused.
    private var isAtJukebox: Bool {
        readings.track != nil && cardAgent == nil && game.player.distance(to: map.jukebox.center) < 2.4
    }

    private func pressPad(_ command: NowPlayingCommand) {
        store.nowPlaying.send(command)
        store.achievements.record(.jukeboxPresses)
        pressedPad = (command, Date())
    }

    private var recentlyPressedPad: NowPlayingCommand? {
        guard let pressedPad, Date().timeIntervalSince(pressedPad.at) < 0.25 else { return nil }
        return pressedPad.command
    }

    private static func direction(for press: KeyPress) -> OfficeDirection? {
        switch press.key {
        case .upArrow: return .up
        case .downArrow: return .down
        case .leftArrow: return .left
        case .rightArrow: return .right
        default: break
        }
        switch press.characters.lowercased() {
        case "w": return .up
        case "s": return .down
        case "a": return .left
        case "d": return .right
        default: return nil
        }
    }

    private var cardAgent: AgentSession? {
        game.cardPID.flatMap { pid in readings.agents.first { $0.pid == pid } }
    }

    @ViewBuilder
    private func agentCard(camera: OfficeCamera, size: CGSize) -> some View {
        if let agent = cardAgent, let position = map.position(of: agent.pid) {
            let x = camera.screenX(position.x) + camera.tileSize * 2.2
            let y = camera.screenY(position.y) - camera.tileSize * 4.5
            OfficeAgentCard(agent: agent) { game.closeCard() }
                .offset(x: min(max(8, x), size.width - 280), y: min(max(8, y), size.height - 190))
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private func tooltip(size: CGSize) -> some View {
        if let hovered, let text = OfficeTooltipText.text(for: hovered, readings: readings, map: map) {
            OfficeTooltip(text: text)
                .offset(x: min(pointer.x + 14, size.width - 240), y: pointer.y + 16)
                .allowsHitTesting(false)
        }
    }

    private var waitingPIDs: [Int32] {
        NeedsYouFeed.agents(in: readings.agents).map(\.pid)
    }

    /// Fresh requests as posts; older ones shrink into a row of avatars that stays until the agent is answered.
    private var needsYouCorner: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let layout = needsYou.layout(of: readings.agents, now: timeline.date)
            VStack(alignment: .leading, spacing: 10) {
                if !layout.avatars.isEmpty {
                    NeedsYouAvatarRow(agents: layout.avatars, avatarSpace: avatarSpace, walk: walk)
                }
                ForEach(layout.posts) { agent in
                    NeedsYouPost(agent: agent, avatarSpace: avatarSpace, walk: { walk(to: agent.pid) }, shrink: { needsYou.shrink(agent.pid) })
                        .transition(.scale(scale: 0.15, anchor: .topLeading).combined(with: .opacity))
                }
            }
            .animation(.smooth(duration: 0.4), value: layout)
        }
    }

    private func walk(to pid: Int32) {
        isFocused = true
        needsYou.shrink(pid)
        game.select(pid)
    }

    private var hint: some View {
        Text(isAtJukebox ? "Space plays or pauses · Q and E skip tracks · or click the pads"
                         : "WASD or arrows to walk · click to go somewhere · Space opens an agent's terminal")
            .font(.caption)
            .foregroundStyle(theme.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(theme.surface.opacity(0.85), in: Capsule())
            .allowsHitTesting(false)
    }
}

/// Keeps the system audio tap listening while the office is on screen, so the party follows the beat.
private struct OfficeAudioListener: View {
    @Environment(MonitorStore.self) private var store

    var body: some View {
        Color.clear
            .onAppear { store.nowPlaying.visualizerAppeared() }
            .onDisappear { store.nowPlaying.visualizerDisappeared() }
    }
}
