import SwiftUI

struct SessionCardView: View {
    let session: FleetSession
    @EnvironmentObject var vm: FleetViewModel
    @State private var isHovered = false
    @State private var actionFlash: CardFlash? = nil
    @State private var showRolePicker = false

    var isSelected: Bool { vm.selectedId == session.id }
    var isActive: Bool { session.isWorking }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            Spacer().frame(height: 10)
            previewText
            Spacer().frame(height: 12)
            if session.needsAttention {
                actionRow
            } else {
                activeIndicator
            }
        }
        .padding(16)
        .frame(minHeight: 160, alignment: .top)
        .background(cardBackground)
        .overlay(cardBorder)
        .cornerRadius(14)
        .shadow(color: cardShadow, radius: isSelected ? 12 : 0)
        .opacity(isActive ? 0.6 : 1.0)
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(.spring(response: 0.2), value: isHovered)
        .animation(.spring(response: 0.2), value: isSelected)
        .ifCondition(session.needsAttention && actionFlash == nil) { $0.pendingBorder(color: projectColor) }
        .onTapGesture { vm.selectSession(session.id) }
        .onTapGesture(count: 2) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                vm.focusedId = session.id
            }
        }
        .onHover { isHovered = $0 }
        .overlay(flashOverlay)
        .overlay(session.needsAttention ? AnyView(HUDCorners(size: 10, thickness: 1.0, color: projectColor.opacity(0.35))) : AnyView(EmptyView()))
    }

    // MARK: - Header

    private var cardHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            // Avatar
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(avatarBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(avatarBorder, lineWidth: 1)
                    )
                    .frame(width: 32, height: 32)

                if session.isWorking {
                    Image(systemName: "arrow.trianglehead.2.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#34d399"))
                } else if session.risk {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#ff6040"))
                } else {
                    Text(String(session.project.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(projectColor)
                }
            }

            // Title + meta
            VStack(alignment: .leading, spacing: 2) {
                // Project · branch
                HStack(spacing: 4) {
                    Text(session.project)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    if !session.displayBranch.isEmpty {
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.35))
                        Text(session.displayBranch)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "#00d4ff").opacity(0.8))
                    }
                }
                .lineLimit(1)
                // Conversation title (set by Claude Code)
                if !session.displayTitle.isEmpty {
                    Text(session.displayTitle)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    // Status dot
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 5, height: 5)
                        .shadow(color: statusDotColor.opacity(0.7), radius: 3)

                    Text(statusLabel)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))

                    if !session.progressLabel.isEmpty {
                        Text("·")
                            .foregroundColor(.white.opacity(0.2))
                        Text(session.progressLabel)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.3))
                    }

                    if session.risk {
                        RiskBadge(reason: session.riskReason ?? "risky")
                    }
                }

                // Role pill — tap to change role
                Button(action: { showRolePicker = true }) {
                    Text(FleetRole.named(session.role).name)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(hex: "#00d4ff").opacity(0.65))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#00d4ff").opacity(0.07))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color(hex: "#00d4ff").opacity(0.18), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showRolePicker) {
                    RolePickerView(session: session)
                        .environmentObject(vm)
                }
            }

            Spacer()
        }
    }

    // MARK: - Preview

    private var isAnalyzing: Bool {
        session.stateSummary.contains("Analyzing") || session.stateSummary.starts(with: "Detected:")
    }

    private var previewText: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isAnalyzing {
                HStack(spacing: 8) {
                    Circle()
                        .fill(projectColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: projectColor.opacity(0.8), radius: 4)
                        .pulsing()
                    Text("Analyzing...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(projectColor.opacity(0.8))
                }
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            } else {
                // Last output — what just happened
                if !session.lastOutput.isEmpty {
                    Text(session.lastOutput)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.45))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // State summary
                Text(session.stateSummary)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            // Response type + options (if paused)
            if !isAnalyzing && !session.options.isEmpty && session.needsAttention {
                HStack(spacing: 4) {
                    // Type badge
                    Text(session.responseType == "confirm" ? "CONFIRM" :
                         session.responseType == "choose" ? "CHOOSE" : "INPUT")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(projectColor.opacity(0.6))
                        .tracking(0.8)
                    // Option pills
                    ForEach(session.options, id: \.self) { opt in
                        Text(opt)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                            .cornerRadius(5)
                    }
                }
            }

            // Suggested action
            if !isAnalyzing && session.needsAttention && !session.suggestedAction.isEmpty {
                Text(session.suggestedAction)
                    .font(.system(size: 11))
                    .foregroundColor(projectColor.opacity(0.55))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    // MARK: - Action row (for needsAttention sessions: idle or paused)

    private var actionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Continue button
                Button(action: {
                    withAnimation(.spring(response: 0.25)) {
                        actionFlash = .approve
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        actionFlash = nil
                        vm.continueSession(session)
                    }
                }) {
                    Label("Continue", systemImage: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ApproveButtonStyle())

                // Deny button — only for paused sessions
                if session.isPaused {
                    Button(action: {
                        withAnimation(.spring(response: 0.25)) {
                            actionFlash = .deny
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            actionFlash = nil
                            vm.deny(session)
                        }
                    }) {
                        Label("Deny", systemImage: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DenyButtonStyle())
                }

                // Jump to iTerm2 window
                Button(action: { vm.jumpToSession(session) }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 13))
                }
                .buttonStyle(IconButtonStyle())
                .help("Jump to terminal")

                // Kill session
                Button(action: { vm.killSession(session) }) {
                    Image(systemName: "xmark.square")
                        .font(.system(size: 13))
                }
                .buttonStyle(IconButtonStyle())
                .help("Kill session")
            }
        }
    }

    @ViewBuilder
    private var activeIndicator: some View {
        if session.isDone {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#34d399"))
                Text("Done — ready for next task")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "#34d399").opacity(0.9))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: "#34d399").opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#34d399").opacity(0.2), lineWidth: 1))
            .cornerRadius(6)
        } else if let sent = session.autoSent, sent != "running" && sent != "idle" {
            Text("Auto: \(sent)")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.2))
        } else if session.isWorking {
            Text(session.stateSummary.isEmpty ? "Working…" : session.stateSummary)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.2))
        } else {
            Text(session.stateSummary.isEmpty ? "Watching…" : session.stateSummary)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.2))
        }
    }

    // MARK: - Flash overlay

    private var flashOverlay: some View {
        Group {
            if let flash = actionFlash {
                RoundedRectangle(cornerRadius: 14)
                    .fill(flash == .approve
                          ? Color(hex: "#00d4ff").opacity(0.12)
                          : Color(hex: "#ff6040").opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                flash == .approve
                                    ? Color(hex: "#00d4ff").opacity(0.6)
                                    : Color(hex: "#ff6040").opacity(0.6),
                                lineWidth: 1.5
                            )
                    )
            }
        }
    }

    // MARK: - Style helpers

    // Deterministic color per project name
    private var projectColor: Color {
        let colors: [Color] = [
            Color(hex: "#00d4ff"), // cyan
            Color(hex: "#7c3aed"), // violet
            Color(hex: "#00ff88"), // green
            Color(hex: "#ff6b35"), // orange
            Color(hex: "#4d9fff"), // blue
            Color(hex: "#ff2d78"), // pink
            Color(hex: "#fbbf24"), // amber
            Color(hex: "#34d399"), // emerald
        ]
        let hash = abs(session.project.hashValue)
        return colors[hash % colors.count]
    }

    private var cardBackground: some View {
        Group {
            if session.risk {
                Color(hex: "#ff3c1e").opacity(0.04)
            } else if isSelected {
                projectColor.opacity(0.06)
            } else {
                Color.white.opacity(isHovered ? 0.05 : 0.035)
            }
        }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 14)
            .stroke(borderColor, lineWidth: 1)
    }

    private var borderColor: Color {
        if let flash = actionFlash {
            return flash == .approve ? projectColor.opacity(0.6) : Color(hex: "#ff6040").opacity(0.6)
        }
        if session.risk { return Color(hex: "#ff5032").opacity(0.3) }
        if isSelected   { return projectColor.opacity(0.4) }
        if isHovered    { return projectColor.opacity(0.18) }
        return projectColor.opacity(0.08)
    }

    private var cardShadow: Color {
        if isSelected && !session.risk { return projectColor.opacity(0.12) }
        return .clear
    }

    private var avatarBg: Color {
        if session.risk { return Color(hex: "#ff6040").opacity(0.1) }
        return projectColor.opacity(session.isWorking ? 0.06 : 0.1)
    }

    private var avatarBorder: Color {
        if session.risk { return Color(hex: "#ff6040").opacity(0.25) }
        return projectColor.opacity(session.isWorking ? 0.12 : 0.25)
    }

    private var statusDotColor: Color {
        if session.isHigh    { return Color(hex: "#ff6040") }
        if session.isWorking { return Color(hex: "#34d399") }
        return projectColor
    }

    private var statusLabel: String {
        switch session.status {
        case "idle":    return "idle — needs instruction"
        case "paused":  return "paused — waiting for input"
        case "working": return "working"
        case "done":    return "done — ready for next task"
        default:        return session.status
        }
    }
}

// MARK: - Risk Badge

struct RiskBadge: View {
    let reason: String
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 8, weight: .bold))
            Text(reason.prefix(20))
                .font(.system(size: 9.5, weight: .bold))
        }
        .foregroundColor(Color(hex: "#ff6040"))
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color(hex: "#ff3c1e").opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(hex: "#ff5032").opacity(0.25), lineWidth: 1)
        )
        .cornerRadius(4)
    }
}

// MARK: - Flash enum

enum CardFlash { case approve, deny }

// MARK: - Button styles

struct ApproveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(Color(hex: "#00d4ff"))
            .padding(.vertical, 7)
            .background(Color(hex: "#00d4ff").opacity(configuration.isPressed ? 0.22 : 0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "#00d4ff").opacity(configuration.isPressed ? 0.5 : 0.3), lineWidth: 1)
            )
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct DenyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? Color(hex: "#ff6040") : .white.opacity(0.5))
            .padding(.vertical, 7)
            .background(
                configuration.isPressed
                    ? Color(hex: "#ff5032").opacity(0.1)
                    : Color.white.opacity(0.04)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        configuration.isPressed
                            ? Color(hex: "#ff5032").opacity(0.3)
                            : Color.white.opacity(0.1),
                        lineWidth: 1
                    )
            )
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white.opacity(configuration.isPressed ? 0.6 : 0.3))
            .frame(width: 28, height: 28)
            .background(Color.white.opacity(configuration.isPressed ? 0.07 : 0))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .cornerRadius(7)
    }
}
