import SwiftUI

struct DetailSidebarView: View {
    @EnvironmentObject var vm: FleetViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Session Detail")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
                    .tracking(0.5)
                    .textCase(.uppercase)

                Spacer()

                Text("⎋ esc")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.2))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .cornerRadius(4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider().background(Color.white.opacity(0.06))

            if let session = vm.selectedSession {
                SessionDetailView(session: session)
                    .environmentObject(vm)
            } else {
                emptyState
            }
        }
        .background(Color.white.opacity(0.02))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "scope")
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.1))
            Text("Select a session to inspect")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.2))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Session detail (clearance-style layout)

struct SessionDetailView: View {
    let session: FleetSession
    @EnvironmentObject var vm: FleetViewModel
    @State private var detailsExpanded = false

    private var projectColor: Color {
        let colors: [Color] = [
            Color(hex: "#00d4ff"), Color(hex: "#7c3aed"),
            Color(hex: "#00ff88"), Color(hex: "#ff6b35"),
            Color(hex: "#4d9fff"), Color(hex: "#ff2d78"),
            Color(hex: "#fbbf24"), Color(hex: "#34d399"),
        ]
        return colors[abs(session.project.hashValue) % colors.count]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Compact info section
            VStack(alignment: .leading, spacing: 12) {
                // 1. Identity (tiny)
                sessionHeader

                // 2. THE ASK — what does this agent want?
                if let prompt = session.suggestedPrompt {
                    askBlock(prompt: prompt)
                } else if session.needsAttention {
                    needsInstructionBlock
                }

                // 3. Context — one-line summary of where we are
                if !session.stateSummary.isEmpty {
                    Text(session.stateSummary)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                        .lineSpacing(2)
                        .lineLimit(2)
                }

                // 4. Risk warning (only when risky)
                if session.risk { riskBlock }

                // 5. Signal badge — safe / review / risky
                signalBadge
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            Divider().background(Color.white.opacity(0.06))

            // Terminal takes ALL remaining space
            terminalSection
                .frame(maxHeight: .infinity)

            // Details disclosure (collapsed)
            detailsDisclosure
                .padding(.horizontal, 16)
                .padding(.vertical, 4)

            // Pinned action footer
            if session.needsAttention {
                Divider().background(Color.white.opacity(0.06))
                actionFooter
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Session header

    private var sessionHeader: some View {
        HStack(spacing: 6) {
            Text(session.project)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            if !session.displayBranch.isEmpty {
                Text("·")
                    .foregroundColor(.white.opacity(0.25))
                Text(session.displayBranch)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(projectColor.opacity(0.7))
            }
            Spacer()
            Text(FleetRole.named(session.role).name)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(projectColor.opacity(0.6))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(projectColor.opacity(0.07))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(projectColor.opacity(0.15), lineWidth: 0.5))
        }
    }

    // MARK: - The Ask (hero block — first thing you read)

    private func askBlock(prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WILL SEND")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Color(hex: "#00d4ff").opacity(0.4))
                .tracking(1)

            Text(prompt)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "#00d4ff").opacity(0.9))
                .lineSpacing(4)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#00d4ff").opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "#00d4ff").opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(10)
    }

    private var needsInstructionBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NEEDS INSTRUCTION")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(projectColor.opacity(0.5))
                .tracking(1)
            Text("Session is idle — waiting for a prompt")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(projectColor.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(projectColor.opacity(0.15), lineWidth: 1)
        )
        .cornerRadius(10)
    }

    // MARK: - Risk

    @ViewBuilder
    private var riskBlock: some View {
        if let reason = session.riskReason {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#ff6040"))
                Text(reason)
                    .font(.system(size: 11.5))
                    .foregroundColor(Color(hex: "#ff9070").opacity(0.85))
                    .lineLimit(3)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#ff3c1e").opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#ff5032").opacity(0.2), lineWidth: 1))
            .cornerRadius(8)
        }
    }

    // MARK: - Signal badge (replaces confidence bar)

    private var signalBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(signalColor)
                .frame(width: 6, height: 6)
                .shadow(color: signalColor.opacity(0.6), radius: 3)
            Text(signalLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(signalColor.opacity(0.8))
            Spacer()
            if session.progress >= 0 {
                Text("\(session.progress)%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.2))
            }
        }
    }

    private var signalColor: Color {
        if session.risk { return Color(hex: "#ff6040") }
        if session.confidence >= 0.75 { return Color(hex: "#34d399") }
        if session.confidence >= 0.5 { return Color(hex: "#fbbf24") }
        return Color(hex: "#ff6040")
    }

    private var signalLabel: String {
        if session.risk { return "Risky — review carefully" }
        if session.confidence >= 0.75 { return "Safe to approve" }
        if session.confidence >= 0.5 { return "Review recommended" }
        return "Low confidence — review"
    }

    // MARK: - Terminal (always visible, fills remaining space)

    private var terminalSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title bar
            HStack(spacing: 6) {
                Circle().fill(Color(hex: "#34d399").opacity(0.5)).frame(width: 5, height: 5)
                Text("TERMINAL")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.25))
                    .tracking(1.2)
                Spacer()
                Text(session.project)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.12))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: "#0a0a12"))

            // Screenshot or text
            terminalContent
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .cornerRadius(6)
    }

    @ViewBuilder
    private var terminalContent: some View {
        if let ssPath = session.screenshot, FileManager.default.fileExists(atPath: ssPath) {
            let _ = vm.screenshotTick
            if let nsImage = NSImage(contentsOfFile: ssPath) {
                GeometryReader { geo in
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .id("sidebar-ss-\(session.sessionId)-\(vm.screenshotTick)")
                .background(Color.black)
            }
        } else {
            let cleaned = session.cleanLastLines
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0 != ">" }
                .suffix(40)
                .joined(separator: "\n")
            ScrollView(.vertical, showsIndicators: false) {
                Text(cleaned.isEmpty ? "No output captured" : cleaned)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.65))
                    .lineSpacing(3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .background(Color(hex: "#06060c"))
        }
    }

    // MARK: - Details (collapsed by default)

    private var detailsDisclosure: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { detailsExpanded.toggle() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: detailsExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.25))
                        .frame(width: 12)
                    Text("DETAILS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.25))
                        .tracking(1.2)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            if detailsExpanded {
                VStack(alignment: .leading, spacing: 3) {
                    MetaRow(key: "path", value: session.path)
                    MetaRow(key: "branch", value: session.branch)
                    MetaRow(key: "status", value: session.status)
                    if !session.goal.isEmpty {
                        MetaRow(key: "goal", value: session.goal)
                    }
                    if !session.progressLabel.isEmpty {
                        MetaRow(key: "progr…", value: session.progressLabel)
                    }
                    HStack(spacing: 4) {
                        Text("preview")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundColor(.white.opacity(0.22))
                            .frame(width: 44, alignment: .leading)
                        Button(action: {
                            if let url = URL(string: session.portlessURL) {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Text(session.portlessURL)
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundColor(Color(hex: "#00d4ff").opacity(0.7))
                                .underline()
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
        .background(Color.white.opacity(0.02))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .cornerRadius(6)
    }

    // MARK: - Pinned action footer

    private var actionFooter: some View {
        HStack(spacing: 8) {
            Button("✕  Deny") {
                vm.deny(session)
                vm.selectSession(nil)
            }
            .buttonStyle(SidebarDenyStyle())

            Button("✓  Approve") {
                vm.approve(session)
                vm.selectSession(nil)
            }
            .buttonStyle(SidebarApproveStyle())
        }
        .padding(16)
    }
}

// MARK: - Shared helpers

struct MetaRow: View {
    let key: String
    let value: String
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(key)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundColor(.white.opacity(0.22))
                .frame(width: 44, alignment: .leading)
            Text(value)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .lineLimit(2)
        }
    }
}

// MARK: - Sidebar button styles

struct SidebarApproveStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color(hex: "#00d4ff"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(hex: "#00d4ff").opacity(configuration.isPressed ? 0.22 : 0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(hex: "#00d4ff").opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(10)
            .shadow(color: Color(hex: "#00d4ff").opacity(configuration.isPressed ? 0.2 : 0), radius: 10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SidebarDenyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(configuration.isPressed ? Color(hex: "#ff6040") : .white.opacity(0.45))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(configuration.isPressed ? Color(hex: "#ff5032").opacity(0.1) : Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    func flexibleWidth() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
    }
}
