import Foundation

final class DaemonBridge: @unchecked Sendable {

    var onStateUpdate: ((String) -> Void)?
    var onConnectionChange: ((Bool) -> Void)?
    private(set) var attentionCount: Int = 0
    var onAttentionCountChange: ((Int) -> Void)?

    private let fleetDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude-fleet")
    private var fsEventStream: FSEventStreamRef?
    private let socketQueue = DispatchQueue(label: "com.wiking.claude-fleet.socket", qos: .userInitiated)
    private var lastStateJSON: String?

    // MARK: - FSEvents

    func startWatching() {
        let path = fleetDir.path as CFString
        let paths = [path] as CFArray

        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let flags: FSEventStreamCreateFlags =
            UInt32(kFSEventStreamCreateFlagUseCFTypes) |
            UInt32(kFSEventStreamCreateFlagFileEvents)

        guard let stream = FSEventStreamCreate(
            nil,
            { (_, info, numEvents, eventPaths, _, _) in
                guard let info else { return }
                let bridge = Unmanaged<DaemonBridge>.fromOpaque(info).takeUnretainedValue()
                let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
                for path in paths {
                    if path.hasSuffix("state.json") {
                        bridge.readStateFile()
                        break
                    }
                }
            },
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            flags
        ) else {
            NSLog("[DaemonBridge] Failed to create FSEventStream")
            return
        }

        fsEventStream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)

        // Initial read
        readStateFile()
    }

    func stopWatching() {
        if let stream = fsEventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            fsEventStream = nil
        }
    }

    private func readStateFile() {
        let stateURL = fleetDir.appendingPathComponent("state.json")
        guard let data = try? Data(contentsOf: stateURL),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        lastStateJSON = json

        // Parse minimally for attention count (top-level field from daemon)
        if let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let count = parsed["needs_attention"] as? Int {
            if count != attentionCount {
                attentionCount = count
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.onAttentionCountChange?(self.attentionCount)
                }
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.onStateUpdate?(json)
        }
    }

    // MARK: - Socket

    func send(_ command: [String: Any]) {
        socketQueue.async { [weak self] in
            self?.sendSync(command)
        }
    }

    /// Approve all non-risky sessions that need attention. Uses last known state.
    func approveAllSafe() {
        guard let json = lastStateJSON,
              let data = json.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sessions = parsed["sessions"] as? [[String: Any]] else {
            return
        }

        for session in sessions {
            let needsAttention = (session["needs_attention"] as? Bool) == true
            let isRisky = (session["risk"] as? Bool) == true
            guard needsAttention && !isRisky,
                  let sessionId = session["session_id"] as? String else { continue }

            let cmd: [String: Any] = [
                "cmd": "approve",
                "session_id": sessionId,
                "response": "y"
            ]
            socketQueue.async { [weak self] in
                self?.sendSync(cmd)
            }
        }
    }

    private func sendSync(_ command: [String: Any]) {
        let socketPath = fleetDir.appendingPathComponent("fleet.sock").path

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            NSLog("[DaemonBridge] socket() failed: \(errno)")
            DispatchQueue.main.async { [weak self] in self?.onConnectionChange?(false) }
            return
        }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            NSLog("[DaemonBridge] Socket path too long")
            return
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dest in
                for (i, byte) in pathBytes.enumerated() {
                    dest[i] = byte
                }
            }
        }

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard connectResult == 0 else {
            NSLog("[DaemonBridge] connect() failed: \(errno)")
            DispatchQueue.main.async { [weak self] in self?.onConnectionChange?(false) }
            return
        }

        DispatchQueue.main.async { [weak self] in self?.onConnectionChange?(true) }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: command),
              var jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        jsonString += "\n"

        jsonString.withCString { cstr in
            let len = strlen(cstr)
            var sent = 0
            while sent < len {
                let n = Darwin.send(fd, cstr.advanced(by: sent), len - sent, 0)
                if n <= 0 { break }
                sent += n
            }
        }

        // Read response (best-effort, non-blocking with timeout)
        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var buffer = [UInt8](repeating: 0, count: 8192)
        let bytesRead = recv(fd, &buffer, buffer.count - 1, 0)
        if bytesRead > 0 {
            // Response received — could parse if needed
            // For now we just confirm the connection works
        }
    }

    // MARK: - Command mapping (web UI → daemon protocol)

    func mapAndSend(_ webCommand: [String: Any]) {
        guard let action = webCommand["action"] as? String else { return }

        var cmd: [String: Any]

        switch action {
        case "approve":
            cmd = [
                "cmd": "approve",
                "session_id": webCommand["sessionId"] as? String ?? "",
                "response": webCommand["response"] as? String ?? "y"
            ]
        case "deny":
            cmd = [
                "cmd": "deny",
                "session_id": webCommand["sessionId"] as? String ?? "",
                "response": webCommand["response"] as? String ?? "n"
            ]
        case "continue":
            cmd = [
                "cmd": "continue",
                "session_id": webCommand["sessionId"] as? String ?? "",
                "prompt": webCommand["prompt"] as? String ?? ""
            ]
        case "scan":
            cmd = ["cmd": "scan"]
        case "setMode":
            cmd = [
                "cmd": "set_mode",
                "mode": webCommand["mode"] as? String ?? ""
            ]
        case "setRole":
            cmd = [
                "cmd": "set_role",
                "session_id": webCommand["sessionId"] as? String ?? "",
                "role": webCommand["role"] as? String ?? ""
            ]
        case "setRoleGlobal":
            cmd = [
                "cmd": "set_role",
                "role": webCommand["role"] as? String ?? ""
            ]
        case "setGoal":
            cmd = [
                "cmd": "set_goal",
                "project": webCommand["project"] as? String ?? "",
                "goal": webCommand["goal"] as? String ?? ""
            ]
        case "approveAllSafe":
            approveAllSafe()
            return
        default:
            NSLog("[DaemonBridge] Unknown action: \(action)")
            return
        }

        send(cmd)
    }
}
