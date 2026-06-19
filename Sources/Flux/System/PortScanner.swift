import Foundation

/// Finds processes listening on local TCP ports by shelling out to `lsof`.
///
/// `lsof` is the pragmatic choice here — enumerating socket file descriptors
/// natively (`proc_pidfdinfo`) is far more code for the same result. It only
/// sees the current user's processes without elevated privileges, which is
/// exactly the scope we want (the user's own dev servers).
enum PortScanner {
    /// Run `lsof` and parse listening TCP sockets. Blocking — call off-main.
    static func listeningServers() -> [DevServer] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        // +c0: full command names; -nP: no DNS/port-name lookups (fast, numeric).
        process.arguments = ["+c0", "-nP", "-iTCP", "-sTCP:LISTEN"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do { try process.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let output = String(data: data, encoding: .utf8) else { return [] }
        return parse(output)
    }

    /// Parse `lsof` output into one `DevServer` per port.
    static func parse(_ output: String) -> [DevServer] {
        var byPort: [Int: DevServer] = [:]

        for line in output.split(separator: "\n").dropFirst() {  // skip header
            let columns = line.split(separator: " ", omittingEmptySubsequences: true)
            guard
                columns.count >= 9,
                // The address token is the only one containing ':' (e.g.
                // "127.0.0.1:3000", "*:8080", "[::1]:5432"); "(LISTEN)" has none.
                let address = columns.last(where: { $0.contains(":") }),
                let colon = address.lastIndex(of: ":"),
                let port = Int(address[address.index(after: colon)...])
            else { continue }

            if byPort[port] == nil {
                // lsof escapes spaces in command names as \x20.
                let command = String(columns[0]).replacingOccurrences(of: "\\x20", with: " ")
                byPort[port] = DevServer(id: port, command: command, pid: Int32(columns[1]) ?? -1)
            }
        }

        // Tie each server to its git project (working dir → repo → branch).
        return byPort.values
            .map { server in
                var server = server
                if let project = ProjectInfo.project(for: server.pid) {
                    server.projectName = project.name
                    server.gitBranch = project.branch
                }
                return server
            }
            .sorted { $0.port < $1.port }
    }
}
