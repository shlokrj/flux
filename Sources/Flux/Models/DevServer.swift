import Foundation

/// A process listening on a local TCP port — i.e. a likely dev server
/// (Vite on :5173, Postgres on :5432, a Flask app on :5000, …).
struct DevServer: Identifiable, Hashable {
    /// Port number, also the stable row id (deduped per port).
    let id: Int
    var port: Int { id }
    let command: String
    let pid: Int32
    /// The git project the process runs in, if it could be inferred.
    var projectName: String? = nil
    var gitBranch: String? = nil
}
