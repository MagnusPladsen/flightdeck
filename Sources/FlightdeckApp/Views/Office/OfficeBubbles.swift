import MonitorCore
import SwiftUI

/// Thought and speech bubbles over agents: in full near the player, as a small icon further away.
struct OfficeBubbles {
    static let fullBubbleDistance = 6.5

    let scene: OfficeScene
    let pen: OfficePen
    let time: Double

    func draw() {
        for desk in scene.map.desks {
            guard let pid = desk.agentPID, let agent = scene.agents[pid], let position = scene.map.position(of: pid) else { continue }
            let pose = scene.map.poses[pid] ?? .phone
            let spriteHeight = Double(OfficeCharacters.sprite(for: pose, frame: 0).height)
            let (x, y) = OfficePen.pixels(position)
            let anchor = pen.point(x, y - spriteHeight - 2)
            if pid == scene.spotlightPID || position.distance(to: scene.player) < Self.fullBubbleDistance {
                drawFull(OfficeBubbleContent(agent: agent, pose: pose, date: Date(timeIntervalSinceReferenceDate: time)), above: anchor)
            } else {
                drawIcon(OfficeBubbleContent(agent: agent, pose: pose, date: Date(timeIntervalSinceReferenceDate: time)), above: anchor)
            }
        }
    }

    private var scale: Double { pen.camera.scale }

    private func drawFull(_ content: OfficeBubbleContent, above anchor: CGPoint) {
        let text = Text(content.title).bold() + Text(content.title.isEmpty || content.body.isEmpty ? content.body : " " + content.body)
        let resolved = pen.context.resolve(text.font(.system(size: max(9, 4.2 * scale), design: .rounded)).foregroundStyle(Color(hex: 0x24262B)))
        let maxWidth = (OfficeCamera.tilePixels * 3 - 6) * scale
        let size = resolved.measure(in: CGSize(width: maxWidth, height: 80 * scale))
        let padding = 2.5 * scale
        let box = CGRect(x: anchor.x - size.width / 2 - padding, y: anchor.y - size.height - padding * 2 - 2 * scale,
                         width: size.width + padding * 2, height: size.height + padding * 2)
        drawBubble(box, content: content)
        pen.context.draw(resolved, in: box.insetBy(dx: padding, dy: padding))
    }

    private func drawIcon(_ content: OfficeBubbleContent, above anchor: CGPoint) {
        let side = 8 * scale
        let box = CGRect(x: anchor.x - side / 2, y: anchor.y - side - 2 * scale, width: side, height: side)
        drawBubble(box, content: content)
        let icon = pen.context.resolve(Text(content.icon).font(.system(size: 5 * scale, weight: .heavy, design: .rounded)).foregroundStyle(Color(hex: content.accent)))
        pen.context.draw(icon, at: CGPoint(x: box.midX, y: box.midY))
    }

    private func drawBubble(_ box: CGRect, content: OfficeBubbleContent) {
        let shape = Path(roundedRect: box, cornerRadius: min(box.height / 2, 4 * scale))
        pen.context.fill(shape, with: .color(Color(hex: 0xFBFAF6)))
        pen.context.stroke(shape, with: .color(Color(hex: content.accent)), lineWidth: max(1, scale * 0.75))
        if content.isThought {
            for (index, radius) in [1.6, 1.0].enumerated() {
                let dot = CGRect(x: box.midX - radius * scale + Double(index) * 2 * scale, y: box.maxY + (1 + Double(index) * 2.2) * scale,
                                 width: radius * 2 * scale, height: radius * 2 * scale)
                pen.context.fill(Path(ellipseIn: dot), with: .color(Color(hex: 0xFBFAF6)))
                pen.context.stroke(Path(ellipseIn: dot), with: .color(Color(hex: content.accent)), lineWidth: max(1, scale * 0.5))
            }
        } else {
            var tail = Path()
            tail.move(to: CGPoint(x: box.midX - 2 * scale, y: box.maxY - 0.5))
            tail.addLine(to: CGPoint(x: box.midX, y: box.maxY + 2.5 * scale))
            tail.addLine(to: CGPoint(x: box.midX + 2 * scale, y: box.maxY - 0.5))
            pen.context.fill(tail, with: .color(Color(hex: 0xFBFAF6)))
        }
    }
}

/// What an agent's bubble says, by pose.
struct OfficeBubbleContent {
    var title: String
    var body: String
    var icon: String
    var accent: UInt32
    var isThought: Bool

    static let maxBodyLength = 54

    init(agent: AgentSession, pose: OfficePose, date: Date) {
        let action = agent.actionLine
        switch pose {
        case .typing: (title, body, icon, accent, isThought) = (action.verb, action.detail, "•••", 0x7C8796, true)
        case .relaxed: (title, body, icon, accent, isThought) = ("Your turn:", action.detail, "»", 0x4E9F5B, false)
        case .impatient: (title, body, icon, accent, isThought) = ("Needs approval:", action.detail, "!", 0xF29D38, false)
        case .puzzled: (title, body, icon, accent, isThought) = ("Stuck?", agent.stuckReason?.summary ?? action.detail, "?", 0xD9A520, true)
        case .phone: (title, body, icon, accent, isThought) = ("", IdleThoughts.line(for: agent.pid, at: date), "~", 0x9C86D6, true)
        }
        if body.count > Self.maxBodyLength { body = String(body.prefix(Self.maxBodyLength - 1)) + "…" }
    }
}
