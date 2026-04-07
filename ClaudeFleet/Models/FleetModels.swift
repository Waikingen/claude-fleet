import Foundation

// MARK: - Mode

enum FleetMode: String, CaseIterable, Codable, Identifiable {
    case scout, semi, autopilot
    var id: String { rawValue }

    var label: String {
        switch self {
        case .scout:     return "Scout"
        case .semi:      return "Semi"
        case .autopilot: return "Autopilot"
        }
    }

    var description: String {
        switch self {
        case .scout:     return "Manual review"
        case .semi:      return "Auto-approve safe"
        case .autopilot: return "Fully autonomous"
        }
    }
}

// MARK: - Session

struct FleetSession: Identifiable, Codable {
    let sessionId:   String
    let title:       String?
    let project:     String
    let repo:        String
    let branch:      String
    let path:        String
    let lastLines:   String
    let action:      String    // "respond" | "continue" | "qa" | "pending"
    let waitingFor:  String
    let options:     [String]
    let recommended: String?
    let confidence:  Double
    let risk:        Bool
    let riskReason:  String?
    let decision:    String?
    let blocked:     Bool
    let autoSent:    String?
    let tsPaused:    String?
    let role:        String

    var id: String { sessionId }

    // Derived — what state is this session in?
    var needsReview: Bool { action == "respond" && autoSent == nil }
    var isQA:        Bool { action == "qa" }
    var isPending:   Bool { action == "pending" }
    var isRunning:   Bool { action == "continue" || autoSent == "running" }
    var isIdle:      Bool { autoSent == "idle" }

    var displayRepo:   String { repo.isEmpty ? project : repo }
    var displayBranch: String { branch.isEmpty ? "" : branch }
    var displayTitle:  String { title ?? "" }
    var displayFile:   String {
        if let t = title, !t.isEmpty { return t }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    var cleanLastLines: String {
        let ansi = try? NSRegularExpression(pattern: #"\x1B\[[0-9;]*[mGKHF]|\x1B\[[\?][0-9;]*[hl]|\x1B[>=]|\r"#)
        let stripped = ansi?.stringByReplacingMatches(
            in: lastLines,
            range: NSRange(lastLines.startIndex..., in: lastLines),
            withTemplate: ""
        ) ?? lastLines
        return stripped
    }

    var elapsedLabel: String {
        guard let ts = tsPaused,
              let date = ISO8601DateFormatter().date(from: ts) else { return "" }
        let secs = Int(-date.timeIntervalSinceNow)
        if secs < 60   { return "\(secs)s ago" }
        if secs < 3600 { return "\(secs / 60)m ago" }
        return "\(secs / 3600)h ago"
    }

    // MARK: - Codable (custom to handle backward compat + optional action field)

    enum CodingKeys: String, CodingKey {
        case sessionId  = "session_id"
        case title, project, repo, branch, path
        case lastLines  = "last_lines"
        case action
        case waitingFor = "waiting_for"
        case options, recommended, confidence, risk
        case riskReason = "risk_reason"
        case decision
        case blocked
        case autoSent   = "auto_sent"
        case tsPaused   = "ts_paused"
        case role
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionId   = try c.decode(String.self, forKey: .sessionId)
        title       = try? c.decode(String.self, forKey: .title)
        project     = (try? c.decode(String.self, forKey: .project)) ?? ""
        repo        = (try? c.decode(String.self, forKey: .repo)) ?? ""
        branch      = (try? c.decode(String.self, forKey: .branch)) ?? ""
        path        = (try? c.decode(String.self, forKey: .path)) ?? ""
        lastLines   = (try? c.decode(String.self, forKey: .lastLines)) ?? ""
        waitingFor  = (try? c.decode(String.self, forKey: .waitingFor)) ?? ""
        options     = (try? c.decode([String].self, forKey: .options)) ?? []
        recommended = try? c.decode(String.self, forKey: .recommended)
        confidence  = (try? c.decode(Double.self, forKey: .confidence)) ?? 0
        risk        = (try? c.decode(Bool.self, forKey: .risk)) ?? false
        riskReason  = try? c.decode(String.self, forKey: .riskReason)
        decision    = try? c.decode(String.self, forKey: .decision)
        blocked     = (try? c.decode(Bool.self, forKey: .blocked)) ?? false
        autoSent    = try? c.decode(String.self, forKey: .autoSent)
        tsPaused    = try? c.decode(String.self, forKey: .tsPaused)
        role        = (try? c.decode(String.self, forKey: .role)) ?? "builder"

        // Backward compat: derive action from autoSent if field absent
        if let a = try? c.decode(String.self, forKey: .action), !a.isEmpty {
            action = a
        } else {
            switch autoSent {
            case nil:       action = "respond"
            case "qa":      action = "qa"
            case "pending": action = "pending"
            default:        action = "continue"
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(sessionId,   forKey: .sessionId)
        try c.encodeIfPresent(title,       forKey: .title)
        try c.encode(project,     forKey: .project)
        try c.encode(repo,        forKey: .repo)
        try c.encode(branch,      forKey: .branch)
        try c.encode(path,        forKey: .path)
        try c.encode(lastLines,   forKey: .lastLines)
        try c.encode(action,      forKey: .action)
        try c.encode(waitingFor,  forKey: .waitingFor)
        try c.encode(options,     forKey: .options)
        try c.encodeIfPresent(recommended, forKey: .recommended)
        try c.encode(confidence,  forKey: .confidence)
        try c.encode(risk,        forKey: .risk)
        try c.encodeIfPresent(riskReason,  forKey: .riskReason)
        try c.encodeIfPresent(decision,    forKey: .decision)
        try c.encode(blocked,     forKey: .blocked)
        try c.encodeIfPresent(autoSent,    forKey: .autoSent)
        try c.encodeIfPresent(tsPaused,    forKey: .tsPaused)
        try c.encode(role,             forKey: .role)
    }
}

// MARK: - State

struct FleetState: Codable {
    var phase:         String
    var mode:          String
    var sessions:      [FleetSession]
    var totalSessions: Int
    var pausedCount:   Int
    var autoResolved:  Int
    var needsReview:   Int
    var updated:       String?

    static var empty: FleetState {
        FleetState(phase: "idle", mode: "scout", sessions: [],
                   totalSessions: 0, pausedCount: 0,
                   autoResolved: 0, needsReview: 0, updated: nil)
    }

    enum CodingKeys: String, CodingKey {
        case phase, mode, sessions, updated
        case totalSessions = "total_sessions"
        case pausedCount   = "paused_count"
        case autoResolved  = "auto_resolved"
        case needsReview   = "needs_review"
    }
}

// MARK: - Toast

struct ToastMessage: Identifiable {
    let id = UUID()
    let text: String
    let isError: Bool
}

// MARK: - Role

struct FleetRole: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String

    static let all: [FleetRole] = [
        FleetRole(id: "builder",  name: "Builder",  description: "Keep implementing. Approve most things."),
        FleetRole(id: "yeoman",   name: "Yeoman",   description: "Say yes to everything non-destructive."),
        FleetRole(id: "cautious", name: "Cautious",  description: "Conservative. Surface more for review."),
        FleetRole(id: "reviewer", name: "Reviewer",  description: "Flag completed work as QA."),
        FleetRole(id: "shipper",  name: "Shipper",   description: "Aggressively approve build/deploy steps."),
        FleetRole(id: "scout",    name: "Scout",     description: "Never auto-respond. Observe only."),
    ]

    static func named(_ id: String) -> FleetRole {
        all.first { $0.id == id } ?? all[0]
    }
}
