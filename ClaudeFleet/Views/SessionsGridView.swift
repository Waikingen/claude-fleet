import SwiftUI

struct SessionsGridView: View {
    @EnvironmentObject var vm: FleetViewModel

    private let columns = [GridItem(.adaptive(minimum: 290, maximum: 420), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {

            // Needs attention (idle + paused)
            if !vm.attentionSessions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SectionLabel(text: "Needs Attention")
                        Spacer()
                        Button("Continue all safe  ⌘↵") {
                            vm.approveAllSafe()
                        }
                        .buttonStyle(ApproveAllButtonStyle())
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(vm.attentionSessions) { session in
                            SessionCardView(session: session)
                                .environmentObject(vm)
                        }
                    }
                }
            }

            // Working sessions
            if !vm.workingSessions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Working")

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(vm.workingSessions) { session in
                            SessionCardView(session: session)
                                .environmentObject(vm)
                        }
                    }
                }
            }

            // Empty state
            if vm.sessions.isEmpty {
                EmptyStateView()
                    .environmentObject(vm)
            }
        }
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white.opacity(0.25))
            .tracking(0.06 * 11)
            .textCase(.uppercase)
    }
}

struct ApproveAllButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(Color(hex: "#00d4ff").opacity(configuration.isPressed ? 1.0 : 0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(hex: "#00d4ff").opacity(configuration.isPressed ? 0.18 : 0.08))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#00d4ff").opacity(0.2), lineWidth: 1))
            .cornerRadius(6)
    }
}

struct EmptyStateView: View {
    @EnvironmentObject var vm: FleetViewModel

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: vm.totalCount > 0 ? "checkmark.circle" : "bolt.slash")
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.15))
            Text(vm.totalCount > 0 ? "All sessions working — none need attention" : "No Claude sessions found")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.2))
            if vm.totalCount > 0 {
                Text("\(vm.workingCount) working · \(vm.idleCount) idle")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.12))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
