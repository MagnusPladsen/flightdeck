import Foundation
import MonitorCore

/// Keeps `status.json` current for the `flightdeck` command, SketchyBar and tmux: rewrites it when the
/// status changes or once a minute, otherwise only refreshes its modification time so readers can tell the app is running.
@MainActor
final class StatusPublisher {
    static let sketchyBarEvent = "flightdeck_update"

    private let url: URL
    private var published: StatusReport?
    private let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

    init(url: URL = StatusFile.defaultURL) {
        self.url = url
    }

    func publish(from store: MonitorStore) {
        let report = StatusReport.collect(agents: store.agents, ports: store.ports, snapshot: store.snapshot, usage: store.usage, appVersion: appVersion, now: Date())
        if !report.needsRewrite(after: published), (try? StatusFile.touch(url)) != nil { return }
        guard (try? StatusFile.write(report, to: url)) != nil else { return }
        published = report
        if store.settings.notifiesSketchyBar { Self.triggerSketchyBar() }
    }

    private static func triggerSketchyBar() {
        guard let sketchybar = CommandRunner.locate("sketchybar") else { return }
        let arguments = ["--trigger", sketchyBarEvent]
        Task.detached { _ = CommandRunner.run(sketchybar, arguments, timeout: 2) }
    }
}
