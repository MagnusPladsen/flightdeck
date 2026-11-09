import Foundation

/// Why alerts are being held back right now.
public enum AlertQuietReason: Equatable, Sendable {
    case paused
    case schedule
    case focus
}

public enum AlertQuietness {
    /// A pause wins over the schedule, and the schedule over a Focus. An unknown Focus state never makes it quiet.
    public static func reason(isPaused: Bool, isInSchedule: Bool, followsFocus: Bool, isFocused: Bool?) -> AlertQuietReason? {
        if isPaused { return .paused }
        if isInSchedule { return .schedule }
        if followsFocus && isFocused == true { return .focus }
        return nil
    }
}
