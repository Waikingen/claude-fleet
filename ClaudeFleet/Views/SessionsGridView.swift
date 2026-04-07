import SwiftUI

struct SessionsGridView: View {
    @EnvironmentObject var vm: FleetViewModel

    private let columns = [GridItem(.adaptive(minimum: 290, maximum: 420), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {

            // Pending section
            if !vm.pendingSessions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SectionLabel(text: "⏸  Paused — Needs Review")
                        Spacer()
                        Button("Approve all safe  ↵") {
                            vm.approveAllSafe()
                        }
                        .buttonStyle(ApproveAllButtonStyle())
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(vm.pendingSessions) { session in
                            SessionCardView(session: session)
                                .environmentObject(vm)
                        }
                    }
                }
            }

            // Active section
            if !vm.activeSessions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "▶  Active — Running")

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(vm.activeSessions) { session in
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

// MARK: - Section label

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

// MARK: - Approve all button style

struct ApproveAllButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(Color(hex: "#00d4ff").opacity(configuration.isPressed ? 1.0 : 0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(hex: "#00d4ff").opacity(configuration.isPressed ? 0.18 : 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(hex: "#00d4ff").opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(6)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    @EnvironmentObject var vm: FleetViewModel

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: vm.totalCount > 0 ? "checkmark.circle" : "bolt.slash")
                .font(.system(size: 28))
                .foregroundColor(vm.totalCount > 0 ? Color(hex: "#34d399").opacity(0.3) : .white.opacity(0.1))
            Text(vm.totalCount > 0 ? "All clear — no sessions paused" : "No sessions found")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.2))
            if vm.totalCount > 0 {
                Text("\(vm.totalCount) iTerm2 windows active, none waiting for input")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.12))
            } else {
                Text("Hit Scan to check iTerm2 for paused Claude sessions")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.12))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
