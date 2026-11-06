import Foundation

/// Finds the tmux pane an agent runs in and the client (outer terminal) showing its session.
public enum TmuxTargets {
    public struct Pane: Sendable, Equatable {
        public var tty: String
        public var sessionName: String
        public var windowID: String
        public var paneID: String
    }

    public struct Client: Sendable, Equatable {
        public var tty: String
        public var pid: Int32
        public var sessionName: String
        public var lastActivity: Int
    }

    public static let paneFormat = ["list-panes", "-a", "-F", "#{pane_tty}\t#{session_name}\t#{window_id}\t#{pane_id}"]
    public static let clientFormat = ["list-clients", "-F", "#{client_tty}\t#{client_pid}\t#{session_name}\t#{client_activity}"]

    public static func parsePanes(_ output: String) -> [Pane] {
        fields(of: output, count: 4).map { Pane(tty: $0[0], sessionName: $0[1], windowID: $0[2], paneID: $0[3]) }
    }

    public static func parseClients(_ output: String) -> [Client] {
        fields(of: output, count: 4).compactMap { field in
            guard let pid = Int32(field[1]) else { return nil }
            return Client(tty: field[0], pid: pid, sessionName: field[2], lastActivity: Int(field[3]) ?? 0)
        }
    }

    public static func pane(forTTY tty: String, in panes: [Pane]) -> Pane? {
        panes.first { $0.tty == tty }
    }

    /// The most recently used client on the pane's session, else the most recent client of any
    /// session (which the caller switches over).
    public static func client(showing pane: Pane, among clients: [Client]) -> Client? {
        let mostRecent: (Client, Client) -> Bool = { $0.lastActivity < $1.lastActivity }
        return clients.filter { $0.sessionName == pane.sessionName }.max(by: mostRecent) ?? clients.max(by: mostRecent)
    }

    private static func fields(of output: String, count: Int) -> [[String]] {
        output.split(separator: "\n")
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
            .filter { $0.count == count }
    }
}
