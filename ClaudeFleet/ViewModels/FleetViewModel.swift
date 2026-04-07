import Foundation
import Combine
import SwiftUI
import UserNotifications

@MainActor
final class FleetViewModel: ObservableObject {

    // MARK: - Published state

    @Published var sessions:      [FleetSession] = []
    @Published var selectedId:    String? = nil
    @Published var mode:          FleetMode = .scout
    @Published var phase:         String = "idle"
    @Published var isScanning:    Bool = false
    @Published var totalCount:    Int = 0
    @Published var idleCount:     Int = 0
    @Published var workingCount:  Int = 0
    @Published var attentionCount: Int = 0
    @Published var toast:         ToastMessage? = nil
    @Published var lastScanDate:  Date? = nil
    @Published var globalRole:    String = "builder"
    @Published var focusedId:     String? = nil  // double-click → focused agent view
    @Published var screenshotTick: Int = 0       // increments on each capture to force image reload

    // MARK: - Derived

    var attentionSessions: [FleetSession] { sessions.filter { $0.needsAttention } }
    var workingSessions:   [FleetSession] { sessions.filter { $0.isWorking } }
    var selectedSession:   FleetSession?  { sessions.first { $0.id == selectedId } }
    var focusedSession:    FleetSession?  { sessions.first { $0.id == focusedId } }

    // MARK: - Private

    private let bridge = FleetBridge.shared
    private var cancellables = Set<AnyCancellable>()
    private var knownAttentionIds = Set<String>()

    // MARK: - Init

    init() {
        applyState(bridge.loadState())
    }

    // MARK: - Watching

    private var screenshotTimer: AnyCancellable?

    func startWatching() {
        bridge.startWatching { }
        bridge.stateChanges
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.applyState(state) }
            .store(in: &cancellables)

        // Capture screenshots every 4s using daemon's window_map.json for correct matching
        screenshotTimer = Timer.publish(every: 4, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.captureScreenshots() }
    }

    // MARK: - Actions

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        FleetSocket.shared.scan()
        captureScreenshots()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.isScanning = false
        }
    }

    func continueSession(_ session: FleetSession, customPrompt: String? = nil) {
        let prompt = customPrompt ?? session.suggestedPrompt
        guard let prompt else {
            showToast("No suggested action for this session", isError: true)
            return
        }
        FleetSocket.shared.continueSession(sessionId: session.sessionId, prompt: prompt) { [weak self] ok in
            if ok {
                self?.showToast("→ Sent: \(prompt.prefix(50))")
                // Recapture screenshot after terminal updates
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self?.captureScreenshots()
                }
            } else {
                self?.showToast("Daemon not running", isError: true)
            }
        }
    }

    func approve(_ session: FleetSession) {
        let response = session.suggestedPrompt ?? "y"
        FleetSocket.shared.approve(sessionId: session.sessionId, response: response) { [weak self] ok in
            if ok { self?.showToast("✓ Approved: \(session.displayFile)") }
        }
    }

    func deny(_ session: FleetSession) {
        FleetSocket.shared.deny(sessionId: session.sessionId, response: "n") { [weak self] ok in
            if ok { self?.showToast("✕ Denied: \(session.displayFile)", isError: true) }
        }
    }

    func approveAllSafe() {
        let safe = attentionSessions.filter { !$0.risk }
        for session in safe { continueSession(session) }
        if safe.isEmpty {
            showToast("No sessions need attention")
        } else {
            showToast("→ Continued \(safe.count) session\(safe.count == 1 ? "" : "s")")
        }
    }

    func setMode(_ newMode: FleetMode) {
        mode = newMode
        FleetSocket.shared.setMode(newMode.rawValue)
        showToast(newMode.description)
    }

    func setRole(for session: FleetSession, role: String) {
        FleetSocket.shared.setRole(sessionId: session.sessionId, role: role)
    }

    func setRoleForProject(_ project: String, role: String) {
        FleetSocket.shared.setRole(project: project, role: role)
    }

    func setGlobalRole(_ role: String) {
        globalRole = role
        FleetSocket.shared.setRole(role: role)
    }

    func killSession(_ session: FleetSession) {
        FleetSocket.shared.kill(sessionId: session.sessionId) { [weak self] ok in
            if ok { self?.showToast("Killed: \(session.project)") }
        }
    }

    func jumpToSession(_ session: FleetSession) {
        FleetSocket.shared.jump(sessionId: session.sessionId)
    }

    func newSession(path: String) {
        FleetSocket.shared.newSession(path: path)
        showToast("Starting new session...")
    }

    func captureScreenshots() {
        // Uses daemon's window_map.json for correct session→window matching.
        // The daemon knows the real iTerm2 session→window relationship via AppleScript.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let home = FileManager.default.homeDirectoryForCurrentUser
            let dir = home.appendingPathComponent(".claude-fleet/screenshots")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            // Read daemon's session→windowID mapping
            let mapPath = home.appendingPathComponent(".claude-fleet/window_map.json")
            guard let data = try? Data(contentsOf: mapPath),
                  let mapping = try? JSONSerialization.jsonObject(with: data) as? [String: Int] else { return }

            var captured = Set<Int>()  // track captured window IDs

            for (sessionId, windowId) in mapping {
                let sessionPath = dir.appendingPathComponent("\(sessionId).png").path
                let tmpPath = dir.appendingPathComponent("tmp-\(windowId).png").path

                // Capture each window only once
                if !captured.contains(windowId) {
                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                    proc.arguments = ["-l", String(windowId), "-x", "-o", tmpPath]
                    try? proc.run()
                    proc.waitUntilExit()
                    captured.insert(windowId)
                }

                // Copy to session-specific path
                if FileManager.default.fileExists(atPath: tmpPath) {
                    try? FileManager.default.removeItem(atPath: sessionPath)
                    try? FileManager.default.copyItem(atPath: tmpPath, toPath: sessionPath)
                }
            }

            // Clean up tmp files
            for wid in captured {
                try? FileManager.default.removeItem(atPath: dir.appendingPathComponent("tmp-\(wid).png").path)
            }

            DispatchQueue.main.async { self?.screenshotTick += 1 }
        }
    }

    func setGoal(project: String, goal: String) {
        FleetSocket.shared.setGoal(project: project, goal: goal)
        showToast("Goal set for \(project)")
    }

    func selectSession(_ id: String?) {
        selectedId = id
    }

    // MARK: - Private

    private func applyState(_ state: FleetState) {
        sessions       = state.sessions
        phase          = state.phase
        totalCount     = state.totalSessions
        idleCount      = state.idleCount
        workingCount   = state.workingCount
        attentionCount = state.needsAttention

        if let modeVal = FleetMode(rawValue: state.mode) {
            mode = modeVal
        }
        if state.phase == "done" {
            lastScanDate = Date()
            isScanning = false
        } else if state.phase == "analyzing" {
            isScanning = true
        }
        // Don't show scan animation for routine "scanning" phase (every 5s sweep)

        // Notify for new attention-needed sessions
        let newAttention = sessions.filter { $0.needsAttention && !knownAttentionIds.contains($0.id) }
        knownAttentionIds = Set(sessions.filter { $0.needsAttention }.map { $0.id })
        for session in newAttention {
            notifySession(session)
        }

        // Sync global role
        let rolesURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude-fleet/roles.json")
        if let data = try? Data(contentsOf: rolesURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let global = json["global"] as? String {
            globalRole = global
        }
    }

    private func showToast(_ text: String, isError: Bool = false) {
        toast = ToastMessage(text: text, isError: isError)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.toast?.text == text { self?.toast = nil }
        }
    }

    private func notifySession(_ session: FleetSession) {
        let content = UNMutableNotificationContent()
        content.title = "Fleet: \(session.project)"
        content.body = session.stateSummary.isEmpty ? "Needs attention" : session.stateSummary
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: session.sessionId, content: content, trigger: nil)
        )
    }
}
