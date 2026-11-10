/// Every achievement there is, in the order the achievements page shows them.
public enum AchievementCatalog {
    public static let all: [Achievement] = agents + habits + system + music + dashboard

    private static let agents: [Achievement] = [
        Achievement("first-flight", "First flight", "Watch an agent work", symbol: "paperplane.fill", .agents, .peakWorkingAgents, goal: 1),
        Achievement("wingman", "Wingman", "Have 2 agents working at once", symbol: "person.2.fill", .agents, .peakWorkingAgents, goal: 2),
        Achievement("squadron", "Squadron", "Have 5 agents working at once", symbol: "person.3.fill", .agents, .peakWorkingAgents, goal: 5),
        Achievement("armada", "Armada", "Have 10 agents working at once", symbol: "airplane", .agents, .peakWorkingAgents, goal: 10),
        Achievement("clocked-in", "Clocked in", "1 hour of agent work", symbol: "clock.fill", .agents, .agentHours, goal: 1),
        Achievement("full-shift", "Full shift", "10 hours of agent work", symbol: "clock.badge.checkmark.fill", .agents, .agentHours, goal: 10),
        Achievement("centurion", "Centurion", "100 hours of agent work", symbol: "shield.lefthalf.filled", .agents, .agentHours, goal: 100),
        Achievement("fleet-commander", "Fleet commander", "1,000 hours of agent work", symbol: "star.circle.fill", .agents, .agentHours, goal: 1000),
        Achievement("back-and-forth", "Back and forth", "10 turns handed back to you", symbol: "arrow.left.arrow.right", .agents, .turns, goal: 10),
        Achievement("pair-programmer", "Pair programmer", "100 turns handed back to you", symbol: "bubble.left.and.bubble.right.fill", .agents, .turns, goal: 100),
        Achievement("conversationalist", "Conversationalist", "1,000 turns handed back to you", symbol: "text.bubble.fill", .agents, .turns, goal: 1000),
        Achievement("permission-granted", "Permission granted", "Approve an agent's request", symbol: "checkmark.seal.fill", .agents, .approvals, goal: 1),
        Achievement("rubber-stamp", "Rubber stamp", "Approve 50 requests", symbol: "seal.fill", .agents, .approvals, goal: 50),
        Achievement("gatekeeper", "Gatekeeper", "Approve 500 requests", symbol: "lock.shield.fill", .agents, .approvals, goal: 500),
        Achievement("juggler", "Juggler", "Run agents in 3 projects", symbol: "circle.grid.cross.fill", .agents, .projects, goal: 3),
        Achievement("portfolio", "Portfolio", "Run agents in 10 projects", symbol: "square.stack.3d.up.fill", .agents, .projects, goal: 10),
        Achievement("liftoff", "Liftoff", "Start an agent from Flightdeck", symbol: "airplane.departure", .agents, .agentsLaunched, goal: 1),
        Achievement("launch-control", "Launch control", "Start 25 agents from Flightdeck", symbol: "dial.high.fill", .agents, .agentsLaunched, goal: 25),
        Achievement("hit-the-ceiling", "Hit the ceiling", "Use up a usage limit", symbol: "gauge.with.dots.needle.100percent", .agents, .limitsHit, goal: 1),
        Achievement("million-token-day", "Million-token day", "1M tokens in a day", symbol: "flame.fill", .agents, .peakDailyMillionTokens, goal: 1),
        Achievement("token-furnace", "Token furnace", "10M tokens in a day", symbol: "flame.circle.fill", .agents, .peakDailyMillionTokens, goal: 10),
    ]

    private static let habits: [Achievement] = [
        Achievement("cleared-for-takeoff", "Cleared for takeoff", "Open Flightdeck", symbol: "checkmark.circle.fill", .habits, .daysUsed, goal: 1),
        Achievement("regular", "Regular", "Use Flightdeck on 30 days", symbol: "calendar", .habits, .daysUsed, goal: 30),
        Achievement("frequent-flyer", "Frequent flyer", "Use Flightdeck on 100 days", symbol: "calendar.badge.checkmark", .habits, .daysUsed, goal: 100),
        Achievement("on-a-roll", "On a roll", "Agents at work 3 days in a row", symbol: "3.circle.fill", .habits, .longestStreak, goal: 3),
        Achievement("week-streak", "Week streak", "Agents at work 7 days in a row", symbol: "7.circle.fill", .habits, .longestStreak, goal: 7),
        Achievement("habit-formed", "Habit formed", "Agents at work 30 days in a row", symbol: "30.circle.fill", .habits, .longestStreak, goal: 30),
        Achievement("night-owl", "Night owl", "An agent working between midnight and 4", symbol: "moon.stars.fill", .habits, .nightOwlNights, goal: 1),
        Achievement("creature-of-the-night", "Creature of the night", "Agents working past midnight on 10 nights", symbol: "moon.zzz.fill", .habits, .nightOwlNights, goal: 10),
        Achievement("early-bird", "Early bird", "An agent working between 5 and 7 in the morning", symbol: "sunrise.fill", .habits, .earlyBirdDays, goal: 1),
        Achievement("weekend-warrior", "Weekend warrior", "Agents working on a weekend", symbol: "beach.umbrella.fill", .habits, .weekendDays, goal: 1),
        Achievement("no-days-off", "No days off", "Agents working on 10 weekend days", symbol: "figure.run", .habits, .weekendDays, goal: 10),
    ]

    private static let system: [Achievement] = [
        Achievement("redline", "Redline", "CPU above 95%", symbol: "thermometer.high", .system, .cpuRedlines, goal: 1),
        Achievement("under-pressure", "Under pressure", "Memory pressure goes critical", symbol: "memorychip.fill", .system, .memoryCrunches, goal: 1),
        Achievement("full-stack", "Full stack", "3 dev servers at once", symbol: "server.rack", .system, .peakDevServers, goal: 3),
        Achievement("server-farm", "Server farm", "8 dev servers at once", symbol: "externaldrive.connected.to.line.below.fill", .system, .peakDevServers, goal: 8),
        Achievement("terminator", "Terminator", "Stop a process", symbol: "xmark.octagon.fill", .system, .processesStopped, goal: 1),
        Achievement("process-reaper", "Process reaper", "Stop 25 processes", symbol: "scissors", .system, .processesStopped, goal: 25),
        Achievement("tidy", "Tidy", "Clean up a worktree", symbol: "sparkles", .system, .worktreesCleaned, goal: 1),
        Achievement("spring-cleaning", "Spring cleaning", "Clean up 25 worktrees", symbol: "leaf.fill", .system, .worktreesCleaned, goal: 25),
        Achievement("disk-liberator", "Disk liberator", "Free 10 GB of build caches", symbol: "internaldrive.fill", .system, .cacheGigabytesCleaned, goal: 10),
        Achievement("gigabyte-goblin", "Gigabyte goblin", "Free 100 GB of build caches", symbol: "trash.fill", .system, .cacheGigabytesCleaned, goal: 100),
    ]

    private static let music: [Achievement] = [
        Achievement("soundtrack", "Soundtrack", "Code to a track", symbol: "music.note", .music, .tracksHeard, goal: 1),
        Achievement("mixtape", "Mixtape", "100 tracks while coding", symbol: "music.note.list", .music, .tracksHeard, goal: 100),
        Achievement("crate-digger", "Crate digger", "1,000 tracks while coding", symbol: "opticaldisc.fill", .music, .tracksHeard, goal: 1000),
        Achievement("background-noise", "Background noise", "10 hours of music", symbol: "headphones", .music, .musicHours, goal: 10),
        Achievement("concert-season", "Concert season", "100 hours of music", symbol: "hifispeaker.2.fill", .music, .musicHours, goal: 100),
        Achievement("office-party", "Office party", "10 minutes of office rave", symbol: "party.popper.fill", .music, .partyMinutes, goal: 10),
        Achievement("rave-til-dawn", "Rave til dawn", "2 hours of office rave", symbol: "sparkles.rectangle.stack.fill", .music, .partyMinutes, goal: 120),
        Achievement("dj", "DJ", "Press a jukebox pad", symbol: "dial.medium.fill", .music, .jukeboxPresses, goal: 1),
        Achievement("resident-dj", "Resident DJ", "Press jukebox pads 50 times", symbol: "slider.horizontal.3", .music, .jukeboxPresses, goal: 50),
        Achievement("open-office", "Open office", "Visit the office", symbol: "building.2.fill", .music, .officeVisits, goal: 1),
        Achievement("office-regular", "Office regular", "Visit the office 50 times", symbol: "building.columns.fill", .music, .officeVisits, goal: 50),
        Achievement("step-count", "Step count", "Walk 1,000 tiles in the office", symbol: "figure.walk", .music, .officeTilesWalked, goal: 1000),
        Achievement("marathon", "Marathon", "Walk 10,000 tiles in the office", symbol: "figure.run.circle.fill", .music, .officeTilesWalked, goal: 10000),
    ]

    private static let dashboard: [Achievement] = [
        Achievement("shortcut", "Shortcut", "Use the command palette", symbol: "command", .dashboard, .paletteUses, goal: 1),
        Achievement("keyboard-pilot", "Keyboard pilot", "Use the command palette 100 times", symbol: "keyboard.fill", .dashboard, .paletteUses, goal: 100),
        Achievement("curious", "Curious", "Ask Claude a question", symbol: "questionmark.bubble.fill", .dashboard, .questionsAsked, goal: 1),
        Achievement("inquisitive", "Inquisitive", "Ask Claude 50 questions", symbol: "sparkle.magnifyingglass", .dashboard, .questionsAsked, goal: 50),
    ]
}
