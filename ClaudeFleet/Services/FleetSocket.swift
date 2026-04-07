import Foundation

/// Sends JSON commands to fleet_daemon.py over ~/.claude-fleet/fleet.sock
final class FleetSocket {
    static let shared = FleetSocket()
    private let socketPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude-fleet/fleet.sock").path

    func send(_ command: [String: Any], completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = (try? self.sendSync(command)) != nil
            DispatchQueue.main.async { completion?(ok) }
        }
    }

    @discardableResult
    private func sendSync(_ command: [String: Any]) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: command)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw FleetSocketError.connectionFailed }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &addr.sun_path) { ptr in
            socketPath.withCString { src in
                let count = min(strlen(src) + 1, ptr.count)
                ptr.copyBytes(from: UnsafeRawBufferPointer(start: src, count: count))
            }
        }

        let connectResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Foundation.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connectResult == 0 else { throw FleetSocketError.connectionFailed }

        _ = data.withUnsafeBytes { write(fd, $0.baseAddress!, data.count) }
        shutdown(fd, SHUT_WR)

        var received = Data()
        var buf = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = read(fd, &buf, buf.count)
            if n <= 0 { break }
            received.append(contentsOf: buf[..<n])
        }

        guard !received.isEmpty,
              let result = try? JSONSerialization.jsonObject(with: received) as? [String: Any]
        else { throw FleetSocketError.badResponse }
        return result
    }

    // MARK: - Convenience

    func approve(sessionId: String, response: String, completion: ((Bool) -> Void)? = nil) {
        send(["cmd": "approve", "session_id": sessionId, "response": response], completion: completion)
    }

    func deny(sessionId: String, response: String, completion: ((Bool) -> Void)? = nil) {
        send(["cmd": "deny", "session_id": sessionId, "response": response], completion: completion)
    }

    func scan() {
        send(["cmd": "scan"])
    }

    func setRole(sessionId: String? = nil, project: String? = nil, role: String) {
        var cmd: [String: Any] = ["cmd": "set_role", "role": role]
        if let sid = sessionId { cmd["session_id"] = sid }
        if let proj = project  { cmd["project"] = proj }
        send(cmd)
    }

    func setMode(_ mode: String) {
        send(["cmd": "set_mode", "mode": mode])
    }

    func continueSession(sessionId: String, prompt: String? = nil, completion: ((Bool) -> Void)? = nil) {
        var cmd: [String: Any] = ["cmd": "continue", "session_id": sessionId]
        if let p = prompt { cmd["prompt"] = p }
        send(cmd, completion: completion)
    }

    func setGoal(project: String, goal: String) {
        send(["cmd": "set_goal", "project": project, "goal": goal])
    }

    func kill(sessionId: String, completion: ((Bool) -> Void)? = nil) {
        send(["cmd": "kill", "session_id": sessionId], completion: completion)
    }

    func jump(sessionId: String) {
        send(["cmd": "jump", "session_id": sessionId])
    }

    func newSession(path: String) {
        send(["cmd": "new_session", "path": path])
    }
}

enum FleetSocketError: LocalizedError {
    case connectionFailed, badResponse
    var errorDescription: String? {
        switch self {
        case .connectionFailed: return "Fleet daemon not running"
        case .badResponse:      return "Invalid response from daemon"
        }
    }
}
