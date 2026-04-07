import SwiftUI

struct TopBarView: View {
    @EnvironmentObject var vm: FleetViewModel
    @Binding var showConfig: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Logo
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#00d4ff"), Color(hex: "#0088cc")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 26, height: 26)
                        .shadow(color: Color(hex: "#00d4ff").opacity(0.4), radius: 6)

                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text("Claude Fleet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .tracking(-0.3)
            }

            divider

            // Pending count
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(hex: "#00d4ff"))
                    .frame(width: 5, height: 5)
                    .shadow(color: Color(hex: "#00d4ff").opacity(0.7), radius: 3)
                    .opacity(vm.pendingCount > 0 ? 1 : 0.4)

                Text("\(vm.pendingCount)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "#00d4ff"))
                Text("waiting")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.35))
            }

            divider

            // Total count
            HStack(spacing: 5) {
                Text("\(vm.totalCount)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Text("windows")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.25))
            }

            Spacer()

            // Mode switcher
            ModeControlView()
                .environmentObject(vm)

            divider

            // Global role menu
            Menu {
                ForEach(FleetRole.all) { role in
                    Button(role.name) {
                        vm.setGlobalRole(role.id)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 10))
                    Text(FleetRole.named(vm.globalRole).name)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(Color(hex: "#00d4ff").opacity(0.75))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(hex: "#00d4ff").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#00d4ff").opacity(0.2), lineWidth: 0.5))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            divider

            // Scan button
            ScanButton()
                .environmentObject(vm)

            divider

            Button(action: { showConfig = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .cornerRadius(7)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .frame(height: 50)
        .background(Color.clear)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 16)
    }
}

// MARK: - Mode Control

struct ModeControlView: View {
    @EnvironmentObject var vm: FleetViewModel

    var body: some View {
        HStack(spacing: 2) {
            ForEach(FleetMode.allCases) { mode in
                ModeButton(mode: mode, isSelected: vm.mode == mode) {
                    vm.setMode(mode)
                }
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(10)
    }
}

struct ModeButton: View {
    let mode: FleetMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(isSelected ? Color(hex: "#00d4ff") : Color.white.opacity(0.25))
                    .frame(width: 4, height: 4)

                Text(mode.label)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(isSelected ? Color(hex: "#00d4ff") : Color.white.opacity(0.4))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(
                isSelected
                    ? Color(hex: "#00d4ff").opacity(0.14)
                    : Color.clear
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        isSelected ? Color(hex: "#00d4ff").opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scan Button

struct ScanButton: View {
    @EnvironmentObject var vm: FleetViewModel

    var body: some View {
        Button(action: { vm.scan() }) {
            HStack(spacing: 6) {
                if vm.isScanning {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.mini)
                        .tint(Color(hex: "#00d4ff"))
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(vm.isScanning ? "Scanning…" : "Scan")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(Color(hex: "#00d4ff"))
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .background(Color(hex: "#00d4ff").opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "#00d4ff").opacity(vm.isScanning ? 0.5 : 0.25), lineWidth: 1)
            )
            .cornerRadius(8)
            .shadow(
                color: vm.isScanning ? Color(hex: "#00d4ff").opacity(0.25) : .clear,
                radius: 8
            )
        }
        .buttonStyle(.plain)
        .disabled(vm.isScanning)
    }
}
