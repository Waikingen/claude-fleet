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
    @Published var pendingCount:  Int = 0
    @Published var totalCount:    Int = 0
    @Published var toast:         ToastMessage? = nil
    @Published var lastScanDate:  Date? = nil
    @Published var errorMessage:  String? = nil
    @Published var globalRole:    String = "builder"

    // MARK: - Derived

    var pendingSessions: [FleetSession] { sessions.filter { $0.needsReview } }
    var activeSessions:  [FleetSession] { sessions.filter { !$0.needsReview } }
    var selectedSession: FleetSession?  { sessions.first { $0.id == selectedId } }

    // MARK: - Private

    private let bridge = FleetBridge.shared
    private var cancellables = Set<AnyCancellable>()
    private var knownPendingIds = Set<String>()

    // MARK: - Init

    init() {
        let saved = bridge.loadState()
        applyState(saved)
    }

    // MARK: - Watching

    func startWatching() {
        bridge.startWatching { }
        bridge.stateChanges
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.applyState(state)
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        errorMessage = nil
        FleetSocket.shared.scan()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isScanning = false
        }
    }

    func approve(_ session: FleetSession) {
        let response = session.recommended ?? session.options.first ?? "y"
        FleetSocket.shared.approve(sessionId: session.sessionId, response: response) { [weak self] ok in
            if ok {
                self?.showToast("✓ Approved: \(session.displayFile)")
                self?.removePending(session.id)
            } else {
                self?.showToast("Daemon not running — start fleet daemon", isError: true)
            }
        }
    }

    func deny(_ session: FleetSession) {
        let response = session.options.last ?? "n"
        FleetSocket.shared.deny(sessionId: session.sessionId, response: response) { [weak self] ok in
            if ok {
                self?.showToast("✕ Denied: \(session.displayFile)", isError: true)
                self?.removePending(session.id)
            }
        }
    }

    func approveAllSafe() {
        let safe = pendingSessions.filter { !$0.risk && !$0.blocked }
        for session in safe {
            approve(session)
        }
        if safe.isEmpty {
            showToast("No safe sessions to approve")
        } else {
            showToast("✓ Approved \(safe.count) safe session\(safe.count == 1 ? "" : "s")")
        }
    }

    func setMode(_ newMode: FleetMode) {
        mode = newMode
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

    func selectSession(_ id: String?) {
        selectedId = id
    }

    // MARK: - Private helpers

    private func applyState(_ state: FleetState) {
        sessions     = state.sessions
        phase        = state.phase
        pendingCount = state.needsReview
        totalCount   = state.totalSessions

        if let modeVal = FleetMode(rawValue: state.mode) {
            mode = modeVal
        }
        if state.phase == "done" {
            lastScanDate = Date()
        }

        // Notify for newly paused sessions
        let newPending = sessions.filter { $0.needsReview && !knownPendingIds.contains($0.id) }
        knownPendingIds = Set(sessions.filter { $0.needsReview }.map { $0.id })
        for session in newPending {
            notifyPaused(session: session)
        }
        // Load current global role from roles.json
        let rolesURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude-fleet/roles.json")
        if let data = try? Data(contentsOf: rolesURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let global = json["global"] as? String {
            globalRole = global
        }
    }

    private func removePending(_ id: String) {
        sessions.removeAll { $0.id == id }
        pendingCount = sessions.filter { $0.needsReview }.count
        if selectedId == id {
            selectedId = nil
        }
    }

    private func showToast(_ text: String, isError: Bool = false) {
        toast = ToastMessage(text: text, isError: isError)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.toast?.text == text {
                self?.toast = nil
            }
        }
    }

    private func notifyPaused(session: FleetSession) {
        let content = UNMutableNotificationContent()
        content.title = "Fleet: \(session.project)"
        content.body = session.waitingFor.isEmpty ? "Waiting for input" : session.waitingFor
        content.sound = .default
        let request = UNNotificationRequest(identifier: session.sessionId, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
