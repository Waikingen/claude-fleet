import SwiftUI
import AppKit

/// Full-screen focused view for a single agent session.
/// Triggered by double-clicking a session card.
struct AgentFocusView: View {
    let session: FleetSession
    @EnvironmentObject var vm: FleetViewModel
    @State private var customPrompt: String = ""
    @State private var isEditingGoal = false
    @State private var goalText = ""

    var body: some View {
        HStack(spacing: 0) {
            // Left: Agent details
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().background(Color.white.opacity(0.06))
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        goalBlock
                        analysisBlock
                        suggestedBlock
                        customPromptBlock
                        actionsBlock
                        metaBlock
                    }
                    .padding(24)
                }
            }
            .frame(maxWidth: .infinity)

            Divider().background(Color.white.opacity(0.06))

            // Right: Terminal screenshot or text
            terminalPanel
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: { withAnimation(.spring(response: 0.3)) { vm.focusedId = nil } }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])

            // Project avatar
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(projectColor.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(projectColor.opacity(0.25), lineWidth: 1))
                    .frame(width: 38, height: 38)
                Text(String(session.project.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(projectColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(session.project)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text(session.branch)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(projectColor.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(projectColor.opacity(0.08))
                        .cornerRadius(4)
                }
                HStack(spacing: 8) {
                    statusBadge
                    if !session.progressLabel.isEmpty {
                        Text(session.progressLabel)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(projectColor.opacity(0.6))
                    }
                }
            }

            Spacer()

            // Jump + Kill
            Button(action: { vm.jumpToSession(session) }) {
                Label("Open Terminal", systemImage: "arrow.up.right.square")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(FocusActionStyle(color: projectColor))

            Button(action: { vm.killSession(session) }) {
                Label("Kill", systemImage: "xmark")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(FocusActionStyle(color: Color(hex: "#ff6040")))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(session.isWorking ? Color(hex: "#34d399") : projectColor)
                .frame(width: 6, height: 6)
                .shadow(color: (session.isWorking ? Color(hex: "#34d399") : projectColor).opacity(0.6), radius: 3)
            Text(session.status)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Goal

    private var goalBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("PROJECT GOAL", systemImage: "target")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.25))
                    .tracking(1)
                Spacer()
                Button(isEditingGoal ? "Save" : "Edit") {
                    if isEditingGoal {
                        vm.setGoal(project: session.project, goal: goalText)
                        isEditingGoal = false
                    } else {
                        goalText = session.goal
                        isEditingGoal = true
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(projectColor.opacity(0.7))
                .buttonStyle(.plain)
            }

            if isEditingGoal {
                TextEditor(text: $goalText)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(minHeight: 80)
                    .background(Color.black.opacity(0.3))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(projectColor.opacity(0.2), lineWidth: 1))
                    .cornerRadius(8)
            } else {
                Text(session.goal.isEmpty ? "No goal set — what should this agent work toward?" : session.goal)
                    .font(.system(size: 13))
                    .foregroundColor(session.goal.isEmpty ? .white.opacity(0.2) : .white.opacity(0.6))
                    .lineSpacing(3)
            }
        }
    }

    // MARK: - Analysis

    private var analysisBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("STATUS", systemImage: "waveform.path")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.25))
                .tracking(1)

            if !session.lastOutput.isEmpty {
                Text(session.lastOutput)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.45))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(6)
            }

            Text(session.stateSummary)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineSpacing(3)

            // Options pills
            if !session.options.isEmpty {
                HStack(spacing: 6) {
                    Text(session.responseType.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(projectColor.opacity(0.5))
                        .tracking(0.8)
                    ForEach(session.options, id: \.self) { opt in
                        Text(opt)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12), lineWidth: 1))
                            .cornerRadius(6)
                    }
                }
            }

            // Confidence bar
            HStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(projectColor.opacity(0.6))
                            .frame(width: geo.size.width * session.confidence)
                    }
                }
                .frame(height: 4)
                Text(String(format: "%.0f%%", session.confidence * 100))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(projectColor.opacity(0.7))
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }

    // MARK: - Suggested action

    private var suggestedBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("SUGGESTED NEXT STEP", systemImage: "sparkles")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.25))
                .tracking(1)

            if !session.suggestedAction.isEmpty {
                Text(session.suggestedAction)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .lineSpacing(3)
            }

            if let prompt = session.suggestedPrompt {
                VStack(alignment: .leading, spacing: 6) {
                    Text("WILL SEND")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(projectColor.opacity(0.4))
                        .tracking(0.8)
                    Text(prompt)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(projectColor.opacity(0.85))
                        .lineSpacing(4)
                        .textSelection(.enabled)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(projectColor.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(projectColor.opacity(0.15), lineWidth: 1))
                .cornerRadius(10)

                Button(action: { vm.continueSession(session) }) {
                    Label("Continue with suggestion", systemImage: "arrow.right.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(FocusPrimaryStyle(color: projectColor))
            }
        }
    }

    // MARK: - Custom prompt

    private var customPromptBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("CUSTOM INSTRUCTION", systemImage: "text.cursor")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.25))
                .tracking(1)

            HStack(spacing: 8) {
                TextField("Type a custom instruction...", text: $customPrompt)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(10)
                    .background(Color.black.opacity(0.25))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .cornerRadius(8)
                    .onSubmit {
                        guard !customPrompt.isEmpty else { return }
                        vm.continueSession(session, customPrompt: customPrompt)
                        customPrompt = ""
                    }

                Button(action: {
                    guard !customPrompt.isEmpty else { return }
                    vm.continueSession(session, customPrompt: customPrompt)
                    customPrompt = ""
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14))
                        .foregroundColor(customPrompt.isEmpty ? .white.opacity(0.15) : projectColor)
                }
                .buttonStyle(.plain)
                .disabled(customPrompt.isEmpty)
            }
        }
    }

    // MARK: - Actions

    private var actionsBlock: some View {
        HStack(spacing: 10) {
            if session.isPaused {
                Button(action: { vm.approve(session) }) {
                    Label("Approve", systemImage: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(FocusPrimaryStyle(color: Color(hex: "#34d399")))

                Button(action: { vm.deny(session) }) {
                    Label("Deny", systemImage: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(FocusActionStyle(color: Color(hex: "#ff6040")))
            }

            // Preview URL
            Button(action: {
                if let url = URL(string: session.portlessURL) { NSWorkspace.shared.open(url) }
            }) {
                Label("Preview", systemImage: "globe")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(FocusActionStyle(color: .white.opacity(0.5)))
        }
    }

    // MARK: - Meta

    private var metaBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("SESSION", systemImage: "info.circle")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.25))
                .tracking(1)
            Group {
                MetaRow(key: "path", value: session.path)
                MetaRow(key: "role", value: FleetRole.named(session.role).name)
                MetaRow(key: "urgency", value: session.urgency)
                MetaRow(key: "preview", value: session.portlessURL)
            }
        }
    }

    // MARK: - Terminal panel (right side)

    private var terminalPanel: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Circle().fill(projectColor.opacity(0.6)).frame(width: 7, height: 7)
                Text(session.project)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text(session.branch)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Screenshot — live updating via screenshotTick
            if let ssPath = session.screenshot,
               FileManager.default.fileExists(atPath: ssPath) {
                let tick = vm.screenshotTick
                if let data = try? Data(contentsOf: URL(fileURLWithPath: ssPath)),
                   let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
                        .padding(.horizontal, 16)
                        .id("ss-\(session.sessionId)-\(tick)")
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: tick)
                }
            }

            // Terminal text
            let cleaned = session.cleanLastLines
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0 != ">" }
                .suffix(60)
                .joined(separator: "\n")
            ScrollView(.vertical, showsIndicators: false) {
                Text(cleaned.isEmpty ? "Scan to capture terminal output" : cleaned)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
                    .lineSpacing(3.5)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: .infinity)
        }
    }

    // MARK: - Project color

    private var projectColor: Color {
        let colors: [Color] = [
            Color(hex: "#00d4ff"), Color(hex: "#7c3aed"),
            Color(hex: "#00ff88"), Color(hex: "#ff6b35"),
            Color(hex: "#4d9fff"), Color(hex: "#ff2d78"),
            Color(hex: "#fbbf24"), Color(hex: "#34d399"),
        ]
        return colors[abs(session.project.hashValue) % colors.count]
    }
}

// MARK: - Focus button styles

struct FocusPrimaryStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(color)
            .background(color.opacity(configuration.isPressed ? 0.2 : 0.1))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.3), lineWidth: 1))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct FocusActionStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(color.opacity(0.8))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(configuration.isPressed ? 0.12 : 0.06))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(color.opacity(0.15), lineWidth: 1))
            .cornerRadius(7)
    }
}
