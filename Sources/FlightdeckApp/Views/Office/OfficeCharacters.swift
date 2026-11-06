import MonitorCore
import SwiftUI

/// The office's people: agents in every pose, and the player.
/// Letters: h hair, s skin, k eyes, m mouth, t shirt, p trousers, b shoes, f phone, g screen glow, d sweat, c cap, u hoodie.
enum OfficeCharacters {
    private static let head = [
        "...hhhhhh...",
        "..hhhhhhhh..",
        "..hssssssh..",
        "..skssssks..",
        "..ssssssss..",
        "...ssmmss...",
        "....ssss....",
    ]

    private static let headLookingDown = [
        "...hhhhhh...",
        "..hhhhhhhh..",
        "..hhsssshh..",
        "..ssssssss..",
        "..skssssks..",
        "...ssssss...",
        "....ssss....",
    ]

    private static let legs = [
        "...pppppp...",
        "...pp..pp...",
        "...pp..pp...",
        "...bb..bb...",
    ]

    private static let typing = [
        PixelSprite(name: "typing-a", rows: head + ["..tttttttt..", ".tttttttttt.", ".tt.tttt.tt.", "..ss....ss.."]),
        PixelSprite(name: "typing-b", rows: head + ["..tttttttt..", ".tttttttttt.", ".tt.tttt.tt.", ".ss......ss."]),
    ]

    private static let phone = [
        PixelSprite(name: "phone-a", rows: headLookingDown + ["..tttttttt..", ".tttttttttt.", ".ttssffsstt.", "..ttsfgstt.."]),
        PixelSprite(name: "phone-b", rows: headLookingDown + ["..tttttttt..", ".tttttttttt.", ".ttssffsstt.", "..ttsgfstt.."]),
    ]

    private static let relaxed = PixelSprite(name: "relaxed", rows: [
        "...hhhhhh...",
        ".thhhhhhhht.",
        "tthsssssshtt",
        "..skssssks..",
        "..ssssssss..",
        "...smmmms...",
        "....ssss....",
        "..tttttttt..",
        "..tttttttt..",
        "..tttttttt..",
        "..tttttttt..",
    ])

    private static let impatient = [
        PixelSprite(name: "impatient-a", rows: head + ["..tttttttt..", ".tttttttttt.", ".ttsssssstt.", "...tttttt..."] + legs),
        PixelSprite(name: "impatient-b", rows: head + ["..tttttttt..", ".tttttttttt.", ".ttsssssstt.", "...tttttt...",
                                                       "...pppppp...", "...pp..pp...", "...pp..bb...", "...bb......."]),
    ]

    private static let puzzled = [
        PixelSprite(name: "puzzled-a", rows: [
            "...hhhhhh...",
            "..hhhhhhhhs.",
            ".dhssssssht.",
            "..skssssksst",
            "..ssssssss t",
            "...ssmss..t.",
            "....ssss..t.",
            "..ttttttttt.",
            ".tttttttttt.",
            ".stttttttt..",
            "...tttttt...",
        ].map { $0.replacingOccurrences(of: " ", with: ".") } + legs),
    ]

    private static let player = [
        PixelSprite(name: "player-a", rows: playerTop + ["...pppppp...", "...pp..pp...", "...pp..pp...", "...bb..bb..."]),
        PixelSprite(name: "player-b", rows: playerTop + ["...pppppp...", "..pp....pp..", "..pp....pp..", "..bb....bb.."]),
    ]

    private static let playerTop = [
        "...cccccc...",
        "..cccccccccc",
        "..hssssssh..",
        "..skssssks..",
        "..ssssssss..",
        "...ssmmss...",
        "....ssss....",
        "..uuuuuuuu..",
        ".uuuuuuuuuu.",
        ".suuuuuuuus.",
        "...uuuuuu...",
    ]

    /// The frame to draw for a pose; frames alternate a few times a second.
    static func sprite(for pose: OfficePose, frame: Int) -> PixelSprite {
        switch pose {
        case .typing: typing[frame % typing.count]
        case .phone: phone[(frame / 3) % phone.count]
        case .relaxed: relaxed
        case .impatient: impatient[frame % impatient.count]
        case .puzzled: puzzled[0]
        }
    }

    static func playerSprite(isWalking: Bool, frame: Int) -> PixelSprite {
        isWalking ? player[frame % player.count] : player[0]
    }

    /// Just the head, for avatars.
    static let face = PixelSprite(name: "face", rows: head)

    static let playerPalette = SpritePalette(colors: [
        "c": 0x2E8B57, "h": 0x3B2416, "s": 0xF1C9A5, "k": 0x1D1D24, "m": 0xB5615A,
        "u": 0xF2C14E, "p": 0x2F3A56, "b": 0x1D1D24,
    ])

    private static let skins: [UInt32] = [0xF1C9A5, 0xE0AC80, 0xC68B59, 0x8D5A3B, 0xFFDBC0]
    private static let hairs: [UInt32] = [0x2B1D14, 0x6B4226, 0xD8B45A, 0xA33B20, 0x1E1E1E, 0x8C8C8C]

    /// Shirt colour by tool; skin and hair vary by process id so neighbours look different.
    static func palette(tool: AgentTool, pid: Int32) -> SpritePalette {
        let seed = Int(pid.magnitude)
        return SpritePalette(colors: [
            "h": hairs[seed % hairs.count], "s": skins[(seed / hairs.count) % skins.count], "k": 0x1D1D24, "m": 0xB5615A,
            "t": shirt(for: tool), "p": 0x2F3A56, "b": 0x1D1D24, "f": 0x2A2A33, "g": 0x8FD3FF, "d": 0x7FC8FF,
        ])
    }

    private static func shirt(for tool: AgentTool) -> UInt32 {
        switch tool {
        case .claude: 0xD97757
        case .codex: 0x3BA99C
        case .gemini: 0x4F7FE0
        case .cursor: 0x8A8F98
        case .opencode: 0x8E6CD8
        case .aider: 0xD9B44A
        }
    }
}
