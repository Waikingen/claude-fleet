import SwiftUI

struct SessionsGridView: View {
    @EnvironmentObject var vm: FleetViewModel

    private let columns = [GridItem(.adaptive(minimum: 290, maximum: 420), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top action bar (only when there are attention sessions)
            if !vm.attentionSessions.isEmpty {
                HStack {
                    Spacer()
                    Button("Continue all safe  ⌘↵") {
                        vm.approveAllSafe()
                    }
                    .buttonStyle(ApproveAllButtonStyle())
                }
            }

            // Flat grid — all sessions together, sorted by urgency
            if !vm.sessions.isEmpty {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(vm.sessions) { session in
                        SessionCardView(session: session)
                            .environmentObject(vm)
                    }
                }
            } else {
                EmptyStateView()
                    .environmentObject(vm)
            }
        }
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
            Text("Hit Cmd+R to scan")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.12))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
