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
    let sessionId:       String
    let title:           String?
    let project:         String
    let branch:          String
    let path:            String
    let lastLines:       String
    let role:            String
    let goal:            String
    // v3: new analysis fields
    let status:          String    // "idle" | "paused" | "working" | "done"
    let stateSummary:    String
    let progress:        Int
    let suggestedAction: String
    let suggestedPrompt: String?
    let confidence:      Double
    let risk:            Bool
    let riskReason:      String?
    let urgency:         String    // "high" | "medium" | "low"
    let autoSent:        String?

    var id: String { sessionId }

    // Derived
    var needsAttention: Bool { (status == "idle" || status == "paused") && autoSent == nil }
    var isIdle:    Bool { status == "idle" }
    var isPaused:  Bool { status == "paused" }
    var isWorking: Bool { status == "working" }
    var isDone:    Bool { status == "done" }
    var isHigh:    Bool { urgency == "high" }

    var displayBranch: String { branch.isEmpty ? "" : branch }
    var displayTitle:  String { title ?? "" }
    var displayFile:   String {
        if let t = title, !t.isEmpty { return t }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    var progressLabel: String {
        if progress < 0 { return "" }
        return "\(progress)%"
    }

    var portlessURL: String {
        "http://\(project).localhost:1355"
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

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case sessionId       = "session_id"
        case title, project, branch, path
        case lastLines       = "last_lines"
        case role, goal, status
        case stateSummary    = "state_summary"
        case progress
        case suggestedAction = "suggested_action"
        case suggestedPrompt = "suggested_prompt"
        case confidence, risk
        case riskReason      = "risk_reason"
        case urgency
        case autoSent        = "auto_sent"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionId       = try c.decode(String.self, forKey: .sessionId)
        title           = try? c.decode(String.self, forKey: .title)
        project         = (try? c.decode(String.self, forKey: .project)) ?? ""
        branch          = (try? c.decode(String.self, forKey: .branch)) ?? ""
        path            = (try? c.decode(String.self, forKey: .path)) ?? ""
        lastLines       = (try? c.decode(String.self, forKey: .lastLines)) ?? ""
        role            = (try? c.decode(String.self, forKey: .role)) ?? "builder"
        goal            = (try? c.decode(String.self, forKey: .goal)) ?? ""
        status          = (try? c.decode(String.self, forKey: .status)) ?? "working"
        stateSummary    = (try? c.decode(String.self, forKey: .stateSummary)) ?? ""
        progress        = (try? c.decode(Int.self, forKey: .progress)) ?? -1
        suggestedAction = (try? c.decode(String.self, forKey: .suggestedAction)) ?? ""
        suggestedPrompt = try? c.decode(String.self, forKey: .suggestedPrompt)
        confidence      = (try? c.decode(Double.self, forKey: .confidence)) ?? 0
        risk            = (try? c.decode(Bool.self, forKey: .risk)) ?? false
        riskReason      = try? c.decode(String.self, forKey: .riskReason)
        urgency         = (try? c.decode(String.self, forKey: .urgency)) ?? "low"
        autoSent        = try? c.decode(String.self, forKey: .autoSent)
    }
}

// MARK: - State

struct FleetState: Codable {
    var phase:          String
    var mode:           String
    var sessions:       [FleetSession]
    var totalSessions:  Int
    var needsAttention: Int
    var idleCount:      Int
    var workingCount:   Int
    var updated:        String?

    static var empty: FleetState {
        FleetState(phase: "idle", mode: "scout", sessions: [],
                   totalSessions: 0, needsAttention: 0,
                   idleCount: 0, workingCount: 0, updated: nil)
    }

    enum CodingKeys: String, CodingKey {
        case phase, mode, sessions, updated
        case totalSessions  = "total_sessions"
        case needsAttention = "needs_attention"
        case idleCount      = "idle_count"
        case workingCount   = "working_count"
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
