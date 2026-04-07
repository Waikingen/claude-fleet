import SwiftUI

struct SessionsGridView: View {
    @EnvironmentObject var vm: FleetViewModel

    private let columns = [GridItem(.adaptive(minimum: 290, maximum: 420), spacing: 12)]

    // Stable-sorted groups
    private var attentionSorted: [FleetSession] {
        vm.attentionSessions.sorted { $0.project < $1.project }
    }
    private var workingSorted: [FleetSession] {
        vm.sessions.filter { $0.isWorking }.sorted { $0.project < $1.project }
    }
    private var restSorted: [FleetSession] {
        vm.sessions.filter { !$0.needsAttention && !$0.isWorking }.sorted { $0.project < $1.project }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top action bar
            if !vm.attentionSessions.isEmpty {
                HStack {
                    Spacer()
                    Button("Continue all safe  ⌘↵") {
                        vm.approveAllSafe()
                    }
                    .buttonStyle(ApproveAllButtonStyle())
                }
            }

            if !vm.sessions.isEmpty {
                // --- Needs You ---
                if !attentionSorted.isEmpty {
                    sectionHeader("Needs You", count: attentionSorted.count, color: Color(hex: "#00d4ff"))
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(attentionSorted) { session in
                            SessionCardView(session: session)
                                .environmentObject(vm)
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: attentionSorted.map(\.id))
                }

                // --- Working ---
                if !workingSorted.isEmpty {
                    sectionHeader("Working", count: workingSorted.count, color: Color(hex: "#34d399"))
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(workingSorted) { session in
                            SessionCardView(session: session)
                                .environmentObject(vm)
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: workingSorted.map(\.id))
                }

                // --- Idle / Done ---
                if !restSorted.isEmpty {
                    sectionHeader("Idle", count: restSorted.count, color: .white.opacity(0.3))
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(restSorted) { session in
                            SessionCardView(session: session)
                                .environmentObject(vm)
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: restSorted.map(\.id))
                }
            } else {
                EmptyStateView()
                    .environmentObject(vm)
            }
        }
    }

    private func sectionHeader(_ title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color.opacity(0.6))
                .tracking(1.2)
            Text("\(count)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(color.opacity(0.35))
            Spacer()
        }
        .padding(.top, 8)
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
