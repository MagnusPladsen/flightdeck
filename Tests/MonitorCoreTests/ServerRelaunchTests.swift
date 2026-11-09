import Foundation
import MonitorCore
import Testing

struct ServerRelaunchTests {
    @Test func plainArgumentsStayReadable() {
        #expect(ServerRelaunch.commandLine(["/usr/local/bin/node", "node_modules/.bin/next", "dev", "--port=3000"]) == "/usr/local/bin/node node_modules/.bin/next dev --port=3000")
    }

    @Test func argumentsWithShellCharactersAreSingleQuoted() {
        #expect(ServerRelaunch.quote("") == "''")
        #expect(ServerRelaunch.quote("my app") == "'my app'")
        #expect(ServerRelaunch.quote("$HOME;rm -rf /") == "'$HOME;rm -rf /'")
        #expect(ServerRelaunch.quote("it's") == #"'it'\''s'"#)
        #expect(ServerRelaunch.quote("`whoami`") == "'`whoami`'")
    }

    @Test func shellCommandRecordsTheOutput() {
        let command = ServerRelaunch.shellCommand(arguments: ["bun", "run", "dev"], logPath: "/logs/my shop-3000.log")
        #expect(command == "/usr/bin/script -q -F '/logs/my shop-3000.log' bun run dev")
    }

    @Test func rewrittenProcessTitlesAndOddArgvCannotBeRelaunched() {
        #expect(ServerRelaunch.isRelaunchable(["node", "server.js"]))
        #expect(!ServerRelaunch.isRelaunchable([]))
        #expect(!ServerRelaunch.isRelaunchable(["next-server (v15.0.0)"]))
        #expect(!ServerRelaunch.isRelaunchable(["node", "-e", "a\nb"]))
    }

    @Test func logFileNameUsesTheFolderAndPort() {
        #expect(ServerRelaunch.logFileName(for: ServerIdentity(folder: "/code/my shop", port: 3000)) == "my_shop-3000.log")
    }

    @Test func logTailStripsColoursAndRedraws() {
        let text = "\u{1B}[32mready\u{1B}[0m in 300ms\r\n\nprogress 10%\rprogress 100%\n\u{1B}]0;title\u{07}Error: boom\n"
        #expect(LogTail.lastLines(of: text, count: 5) == ["ready in 300ms", "progress 100%", "Error: boom"])
        #expect(LogTail.lastLines(of: text, count: 1) == ["Error: boom"])
    }
}
