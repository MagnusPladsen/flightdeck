import MonitorCore
import SwiftUI

/// The needs-you headline in the voice of each layout.
struct LayoutNeedsYou: View {
    @Environment(\.dashboardLayout) private var layout
    var agent: AgentSession?
    var othersCount: Int
    var snooze: (AgentSession) -> Void

    var body: some View {
        switch layout {
        case .editorial: SentenceHeadline(agent: agent, othersCount: othersCount, size: 64, weight: .regular, snooze: snooze)
        case .zen: SentenceHeadline(agent: agent, othersCount: othersCount, size: 44, weight: .light, snooze: snooze)
        case .mission: CrewActionCard(agent: agent, othersCount: othersCount, snooze: snooze)
        case .cockpit: MasterCaution(agent: agent, othersCount: othersCount, snooze: snooze)
        case .terminal: PromptHeadline(agent: agent, othersCount: othersCount)
        default: NeedsYouHero(agent: agent, othersCount: othersCount, snooze: snooze)
        }
    }
}

/// Counts as words, so headlines read like sentences: "Three agents are waiting on you."
enum SentenceWords {
    static func number(_ count: Int, capitalized: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        let word = formatter.string(from: NSNumber(value: count)) ?? "\(count)"
        return capitalized ? word.prefix(1).uppercased() + word.dropFirst() : word
    }

    static func plural(_ count: Int, _ noun: String) -> String {
        "\(number(count)) \(noun)\(count == 1 ? "" : "s")"
    }
}

/// Editorial and Zen: a sentence headline and a short summary paragraph.
private struct SentenceHeadline: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var agent: AgentSession?
    var othersCount: Int
    var size: CGFloat
    var weight: Font.Weight
    var snooze: (AgentSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headline.font(.system(size: size, weight: weight)).tracking(-size * 0.02).lineLimit(3).minimumScaleFactor(0.6)
            Text(summary).font(.system(size: 17)).foregroundStyle(theme.muted).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            if let agent {
                HStack(spacing: 12) {
                    Button("Go to terminal") { store.openInTerminal(agent.workingDirectory) }.buttonStyle(PillButtonStyle(isProminent: true, size: 14))
                    Button("Later") { snooze(agent) }.buttonStyle(PillButtonStyle(size: 14))
                }
            }
        }
    }

    private var headline: Text {
        guard let agent else { return Text("Nothing needs you. ") + Text("Carry on.").italic().foregroundStyle(theme.attention) }
        let waiting = othersCount + 1
        if waiting == 1 {
            let wish = agent.state == .needsApproval ? "wants a yes." : "wants a word."
            return Text("\(agent.displayName) ") + Text(wish).italic().foregroundStyle(theme.attention)
        }
        return Text("\(SentenceWords.number(waiting, capitalized: true)) agents ") + Text("are waiting on you.").italic().foregroundStyle(theme.attention)
    }

    private var summary: String {
        let working = store.agents.filter { $0.state == .working }.count
        let servers = store.devServers.count
        var sentences: [String] = []
        if let agent {
            let action = agent.actionLine
            let age = agent.ageText()
            sentences.append("Latest from \(agent.displayName): \(action.verb.lowercased()) \(action.detail), waiting \(age == "now" ? "since just now" : age).")
        }
        sentences.append("\(SentenceWords.plural(working, "agent").capitalizedFirst) \(working == 1 ? "is" : "are") working and \(SentenceWords.plural(servers, "server")) \(servers == 1 ? "is" : "are") listening.")
        return sentences.joined(separator: " ")
    }
}

/// Mission control: an outlined card calling for crew action.
private struct CrewActionCard: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var agent: AgentSession?
    var othersCount: Int
    var snooze: (AgentSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(agent == nil ? "ALL SYSTEMS NOMINAL" : "◆ CREW ACTION REQUIRED")
                .font(.system(size: 12, weight: .bold)).tracking(2)
                .foregroundStyle(agent == nil ? theme.success : theme.warning)
            if let agent {
                Text(agent.displayName.uppercased()).font(.system(size: 40, weight: .light)).tracking(2).lineLimit(1).minimumScaleFactor(0.5)
                Text("\(agent.actionLine.verb) \(agent.actionLine.detail)").font(.system(size: 15, design: .monospaced)).foregroundStyle(theme.foreground.opacity(0.8)).lineLimit(2)
                Text("\(agent.tool.displayName.uppercased()) · AWAITING CREW \(agent.ageText().uppercased())\(othersCount > 0 ? " · +\(othersCount) MORE" : "")")
                    .font(.system(size: 11, weight: .semibold)).tracking(1.4).foregroundStyle(theme.muted)
                HStack(spacing: 10) {
                    Button("OPEN TERMINAL") { store.openInTerminal(agent.workingDirectory) }.buttonStyle(OutlineCommandStyle(color: theme.warning, isFilled: true))
                    Button("HOLD") { snooze(agent) }.buttonStyle(OutlineCommandStyle(color: theme.foreground))
                }
            } else {
                Text("No crew action needed.").font(.system(size: 40, weight: .ultraLight))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().strokeBorder(agent == nil ? theme.border : theme.warning))
    }
}

/// Cockpit: a caution panel with a zero-padded wait time.
private struct MasterCaution: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var agent: AgentSession?
    var othersCount: Int
    var snooze: (AgentSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(agent == nil ? "STATUS NORMAL" : "▲ MASTER CAUTION")
                    .font(.system(size: 13, weight: .bold, design: .monospaced)).tracking(1.6)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .foregroundStyle(agent == nil ? theme.success : theme.background)
                    .background(agent == nil ? .clear : theme.error)
                    .overlay(Rectangle().strokeBorder(agent == nil ? theme.success : theme.error))
                if othersCount > 0 { Text("+\(othersCount) QUEUED").font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(theme.warning) }
            }
            if let agent {
                Text(agent.displayName.uppercased()).font(.system(size: 54, weight: .bold, design: .monospaced)).foregroundStyle(theme.primary).lineLimit(1).minimumScaleFactor(0.5)
                Text("\(agent.state == .needsApproval ? "APR" : "USR") · \(agent.actionLine.verb.uppercased()) \(agent.actionLine.detail)")
                    .font(.system(size: 14, design: .monospaced)).lineLimit(2)
                HStack(spacing: 10) {
                    Button("ENGAGE TERMINAL") { store.openInTerminal(agent.workingDirectory) }.buttonStyle(OutlineCommandStyle(color: theme.primary, isFilled: true))
                    Button("DEFER") { snooze(agent) }.buttonStyle(OutlineCommandStyle(color: theme.foreground))
                }
            } else {
                Text("NO ACTION").font(.system(size: 54, weight: .bold, design: .monospaced)).foregroundStyle(theme.muted)
            }
        }
    }
}

/// Terminal: the headline as command output.
private struct PromptHeadline: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var agent: AgentSession?
    var othersCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            (Text("$ ").foregroundStyle(theme.primary) + Text("flightdeck needs-you"))
            if store.needsYouGroups.isEmpty {
                Text("✓ nothing is waiting on you").foregroundStyle(theme.success)
            }
            ForEach(store.needsYouGroups.prefix(5)) { group in
                let agent = group.agent
                Button { store.openInTerminal(agent.workingDirectory) } label: {
                    HStack(spacing: 10) {
                        Text(agent.state == .needsApproval ? "◆" : "○").foregroundStyle(agent.state.color(in: theme))
                        Text(agent.displayName).fontWeight(.bold).frame(width: 180, alignment: .leading).lineLimit(1)
                        Text(agent.tool.rawValue).foregroundStyle(theme.muted).frame(width: 70, alignment: .leading)
                        Text("\(agent.actionLine.verb.lowercased()) \(agent.actionLine.detail)").lineLimit(1)
                        Spacer(minLength: 0)
                        Text(agent.ageText()).foregroundStyle(theme.muted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(size: 14, design: .monospaced))
    }
}

/// Square command button with a thin outline, filled for the main action.
struct OutlineCommandStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    var color: Color
    var isFilled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .tracking(1.4)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .foregroundStyle(isFilled ? theme.background : color)
            .background(isFilled ? color : .clear)
            .overlay(Rectangle().strokeBorder(color))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
