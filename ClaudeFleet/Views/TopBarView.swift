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
                    .opacity(vm.attentionCount > 0 ? 1 : 0.4)

                Text("\(vm.attentionCount)")
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

            // Global role picker (custom popover, not system Menu)
            RoleDropdown(globalRole: $vm.globalRole, onSelect: { vm.setGlobalRole($0) })

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

// MARK: - Custom dark role dropdown (replaces system Menu)

struct RoleDropdown: View {
    @Binding var globalRole: String
    let onSelect: (String) -> Void
    @State private var isOpen = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Trigger button
            Button(action: { isOpen.toggle() }) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(hex: "#00d4ff"))
                        .frame(width: 5, height: 5)
                    Text(FleetRole.named(globalRole).name)
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(isOpen ? 0.1 : 0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isOpen, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(FleetRole.all) { role in
                        Button(action: {
                            onSelect(role.id)
                            isOpen = false
                        }) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(globalRole == role.id ? Color(hex: "#00d4ff") : Color.white.opacity(0.15))
                                    .frame(width: 6, height: 6)
                                Text(role.name)
                                    .font(.system(size: 12, weight: globalRole == role.id ? .semibold : .regular))
                                    .foregroundColor(globalRole == role.id ? .white : .white.opacity(0.6))
                                Spacer()
                                Text(role.description.prefix(25))
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.2))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(globalRole == role.id ? Color.white.opacity(0.06) : Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if role.id != FleetRole.all.last?.id {
                            Divider().background(Color.white.opacity(0.06))
                        }
                    }
                }
                .frame(width: 280)
                .background(Color(hex: "#0d1528"))
            }
        }
        .animation(.easeOut(duration: 0.15), value: isOpen)
    }
}
