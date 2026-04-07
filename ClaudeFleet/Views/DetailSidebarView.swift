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

            // Content
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

// MARK: - Session detail

struct SessionDetailView: View {
    let session: FleetSession
    @EnvironmentObject var vm: FleetViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sessionTitle
                    if session.risk { riskBlock }
                    taskSection
                    if session.options.count > 1 { optionsSection }
                    confidenceSection
                    terminalSection
                    metaSection
                }
                .padding(20)
            }

            // Action footer
            if session.needsReview {
                Divider().background(Color.white.opacity(0.06))

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Subviews

    private var sessionTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.displayFile)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .tracking(-0.3)
            Text(session.path)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundColor(.white.opacity(0.28))
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var riskBlock: some View {
        if let reason = session.riskReason {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#ff6040"))
                    Text("Risk Detected")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#ff6040"))
                }
                Text(reason)
                    .font(.system(size: 11.5))
                    .foregroundColor(Color(hex: "#ff9070").opacity(0.85))
                    .lineLimit(3)
            }
            .padding(10)
            .background(Color(hex: "#ff3c1e").opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#ff5032").opacity(0.2), lineWidth: 1))
            .cornerRadius(8)
        }
    }

    private var taskSection: some View {
        DetailSection(label: "Task") {
            Text(session.waitingFor)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .lineSpacing(3)
        }
    }

    private var optionsSection: some View {
        DetailSection(label: "Options") {
            OptionsRowView(options: session.options, recommended: session.recommended)
        }
    }

    private var confidenceSection: some View {
        DetailSection(label: "Confidence") {
            HStack(spacing: 8) {
                ConfidenceBar(value: session.confidence)
                Text(String(format: "%.0f%%", session.confidence * 100))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(confidenceColor(session.confidence))
            }
        }
    }

    private var terminalSection: some View {
        DetailSection(label: "Terminal") {
            let cleaned = session.cleanLastLines
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0 != ">" && !$0.hasPrefix("─") }
                .joined(separator: "\n")
            ScrollView(.vertical) {
                Text(cleaned.isEmpty ? "(no output)" : cleaned)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .lineSpacing(2.5)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 400)
            .background(Color.black.opacity(0.3))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
            .cornerRadius(8)
        }
    }

    private var metaSection: some View {
        DetailSection(label: "Session") {
            VStack(alignment: .leading, spacing: 3) {
                MetaRow(key: "branch", value: session.branch)
                MetaRow(key: "path",   value: session.path)
                MetaRow(key: "paused", value: session.elapsedLabel)
            }
        }
    }

    private func confidenceColor(_ v: Double) -> Color {
        if v >= 0.8 { return Color(hex: "#34d399") }
        if v >= 0.5 { return Color(hex: "#fbbf24") }
        return Color(hex: "#ff6040")
    }
}

// MARK: - Options row (extracted to help compiler)

struct OptionsRowView: View {
    let options: [String]
    let recommended: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(options, id: \.self) { opt in
                    optionChip(opt)
                }
            }
            if let rec = recommended {
                Text("→ \"\(rec)\" recommended")
                    .font(.system(size: 10.5))
                    .foregroundColor(.white.opacity(0.25))
            }
        }
        .flexibleWidth()
    }

    private func optionChip(_ opt: String) -> some View {
        let isRec = opt == recommended
        return Text(opt)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(isRec ? Color(hex: "#00d4ff") : .white.opacity(0.4))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isRec ? Color(hex: "#00d4ff").opacity(0.1) : Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(
                isRec ? Color(hex: "#00d4ff").opacity(0.3) : Color.white.opacity(0.08),
                lineWidth: 1
            ))
            .cornerRadius(5)
    }
}

// MARK: - Helpers

struct DetailSection<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.2))
                .tracking(0.8)
                .textCase(.uppercase)
            content()
        }
    }
}

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

struct ConfidenceBar: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08)).frame(height: 4)
                Capsule()
                    .fill(barColor)
                    .frame(width: geo.size.width * value, height: 4)
            }
        }
        .frame(height: 4)
    }
    private var barColor: Color {
        if value >= 0.8 { return Color(hex: "#34d399") }
        if value >= 0.5 { return Color(hex: "#fbbf24") }
        return Color(hex: "#ff6040")
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

// MARK: - View extension

extension View {
    func flexibleWidth() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
    }
}
