import SwiftUI

struct SessionCardView: View {
    let session: FleetSession
    @EnvironmentObject var vm: FleetViewModel
    @State private var isHovered = false
    @State private var actionFlash: CardFlash? = nil
    @State private var showRolePicker = false

    var isSelected: Bool { vm.selectedId == session.id }
    var isActive: Bool { !session.needsReview }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            Spacer().frame(height: 10)
            previewText
            Spacer().frame(height: 12)
            if !isActive {
                actionRow
            } else {
                activeIndicator
            }
        }
        .padding(16)
        .background(cardBackground)
        .overlay(cardBorder)
        .cornerRadius(14)
        .shadow(color: cardShadow, radius: isSelected ? 12 : 0)
        .opacity(isActive ? 0.6 : 1.0)
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(.spring(response: 0.2), value: isHovered)
        .animation(.spring(response: 0.2), value: isSelected)
        .ifCondition(!isActive && actionFlash == nil) { $0.pendingBorder() }
        .onTapGesture { vm.selectSession(session.id) }
        .onHover { isHovered = $0 }
        .overlay(flashOverlay)
        .overlay(!isActive ? AnyView(HUDCorners(size: 10, thickness: 1.0, color: Color(hex: "#00d4ff").opacity(0.35))) : AnyView(EmptyView()))
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

                if isActive {
                    Image(systemName: "arrow.trianglehead.2.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#34d399"))
                } else if session.risk {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#ff6040"))
                } else {
                    Text(String(session.displayRepo.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#00d4ff"))
                }
            }

            // Title + meta
            VStack(alignment: .leading, spacing: 2) {
                // Repo · branch
                HStack(spacing: 4) {
                    Text(session.displayRepo)
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

                    if !session.elapsedLabel.isEmpty {
                        Text("·")
                            .foregroundColor(.white.opacity(0.2))
                        Text(session.elapsedLabel)
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

    private var previewText: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Terminal snippet — last 3 non-empty lines
            let lines = session.cleanLastLines
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let snippet = lines.suffix(3).joined(separator: "\n")

            if !snippet.isEmpty {
                Text(snippet)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(.white.opacity(0.38))
                    .lineLimit(3)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                session.risk
                                    ? Color(hex: "#ff5032").opacity(0.2)
                                    : Color.white.opacity(0.06),
                                lineWidth: 1
                            )
                    )
                    .cornerRadius(6)
            }

            // Question being asked
            Text(session.waitingFor)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.55))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button(action: {
                withAnimation(.spring(response: 0.25)) {
                    actionFlash = .approve
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    actionFlash = nil
                    vm.approve(session)
                }
            }) {
                Label("Approve", systemImage: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ApproveButtonStyle())

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

            // Jump to session
            Button(action: { /* open iTerm2 window — future */ }) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 13))
            }
            .buttonStyle(IconButtonStyle())
        }
    }

    @ViewBuilder
    private var activeIndicator: some View {
        if session.isQA {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#34d399"))
                Text("Ready for QA")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "#34d399").opacity(0.9))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: "#34d399").opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#34d399").opacity(0.2), lineWidth: 1))
            .cornerRadius(6)
        } else if session.isPending {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#fbbf24"))
                    Text("Decision needed")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#fbbf24").opacity(0.9))
                }
                if let d = session.decision {
                    Text(d)
                        .font(.system(size: 10.5))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(hex: "#fbbf24").opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#fbbf24").opacity(0.2), lineWidth: 1))
            .cornerRadius(6)
        } else if let sent = session.autoSent, sent != "running" && sent != "idle" {
            Text("Auto: \(sent)")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.2))
        } else {
            Text("Running — watching…")
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

    private var cardBackground: some View {
        Group {
            if session.risk {
                Color(hex: "#ff3c1e").opacity(0.04)
            } else if isSelected {
                Color(hex: "#00d4ff").opacity(0.05)
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
            return flash == .approve ? Color(hex: "#00d4ff").opacity(0.6) : Color(hex: "#ff6040").opacity(0.6)
        }
        if session.risk { return Color(hex: "#ff5032").opacity(0.3) }
        if isSelected   { return Color(hex: "#00d4ff").opacity(0.35) }
        return Color.white.opacity(isHovered ? 0.12 : 0.07)
    }

    private var cardShadow: Color {
        if isSelected && !session.risk { return Color(hex: "#00d4ff").opacity(0.1) }
        return .clear
    }

    private var avatarBg: Color {
        if session.isQA      { return Color(hex: "#34d399").opacity(0.12) }
        if session.isPending { return Color(hex: "#fbbf24").opacity(0.1) }
        if session.isRunning { return Color(hex: "#34d399").opacity(0.08) }
        if session.risk      { return Color(hex: "#ff6040").opacity(0.1) }
        return Color(hex: "#00d4ff").opacity(0.1)
    }

    private var avatarBorder: Color {
        if session.isQA      { return Color(hex: "#34d399").opacity(0.3) }
        if session.isPending { return Color(hex: "#fbbf24").opacity(0.25) }
        if session.isRunning { return Color(hex: "#34d399").opacity(0.15) }
        if session.risk      { return Color(hex: "#ff6040").opacity(0.25) }
        return Color(hex: "#00d4ff").opacity(0.2)
    }

    private var statusDotColor: Color {
        if session.isQA      { return Color(hex: "#34d399") }
        if session.isPending { return Color(hex: "#fbbf24") }
        if session.isRunning { return Color(hex: "#34d399").opacity(0.5) }
        if session.risk      { return Color(hex: "#ff6040") }
        return Color(hex: "#00d4ff")
    }

    private var statusLabel: String {
        if session.isQA      { return "qa ready" }
        if session.isPending { return "pending" }
        if session.isRunning { return "running" }
        if session.isIdle    { return "idle" }
        if session.risk      { return "risky" }
        return "waiting"
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
