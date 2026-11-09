import MonitorCore
import Testing

struct AlertQuietnessTests {
    @Test func focusMakesItQuietOnlyWhenFollowed() {
        #expect(AlertQuietness.reason(isPaused: false, isInSchedule: false, followsFocus: true, isFocused: true) == .focus)
        #expect(AlertQuietness.reason(isPaused: false, isInSchedule: false, followsFocus: false, isFocused: true) == nil)
    }

    @Test func unknownOrOffFocusIsNotQuiet() {
        #expect(AlertQuietness.reason(isPaused: false, isInSchedule: false, followsFocus: true, isFocused: nil) == nil)
        #expect(AlertQuietness.reason(isPaused: false, isInSchedule: false, followsFocus: true, isFocused: false) == nil)
    }

    @Test func scheduleAndFocusEachMakeItQuiet() {
        #expect(AlertQuietness.reason(isPaused: false, isInSchedule: true, followsFocus: true, isFocused: false) == .schedule)
        #expect(AlertQuietness.reason(isPaused: false, isInSchedule: true, followsFocus: true, isFocused: true) == .schedule)
    }

    @Test func pauseWinsOverEverything() {
        #expect(AlertQuietness.reason(isPaused: true, isInSchedule: true, followsFocus: true, isFocused: true) == .paused)
        #expect(AlertQuietness.reason(isPaused: true, isInSchedule: false, followsFocus: false, isFocused: nil) == .paused)
    }
}
