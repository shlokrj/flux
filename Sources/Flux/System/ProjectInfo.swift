import Foundation
import Darwin

/// Infers the project a process is working in: its current working directory,
/// the enclosing git repository, and that repo's current branch.
enum ProjectInfo {
    /// A process's current working directory, via `proc_pidinfo`. Works for the
    /// current user's own processes; returns `nil` otherwise.
    static func workingDirectory(pid: Int32) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }

        let path = withUnsafePointer(to: &info.pvi_cdir.vip_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }
        return path.isEmpty ? nil : path
    }

    /// The nearest ancestor of `dir` containing a `.git` entry, or `nil`.
    static func gitRoot(from dir: String) -> String? {
        var url = URL(fileURLWithPath: dir)
        for _ in 0..<40 {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent(".git").path) {
                return url.path
            }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }  // reached "/"
            url = parent
        }
        return nil
    }

    /// The current branch of the repo at `root` (reads `.git/HEAD` directly, no
    /// shelling out). Falls back to a short commit hash for a detached HEAD.
    static func gitBranch(root: String) -> String? {
        let head = URL(fileURLWithPath: root).appendingPathComponent(".git/HEAD")
        guard let contents = try? String(contentsOf: head, encoding: .utf8) else { return nil }
        let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "ref: refs/heads/"
        if trimmed.hasPrefix(prefix) {
            return String(trimmed.dropFirst(prefix.count))
        }
        return String(trimmed.prefix(7))
    }

    /// Project name + branch for a pid, if it sits inside a git repo.
    static func project(for pid: Int32) -> (name: String, branch: String?)? {
        guard let cwd = workingDirectory(pid: pid), let root = gitRoot(from: cwd) else { return nil }
        return (URL(fileURLWithPath: root).lastPathComponent, gitBranch(root: root))
    }
}
