import SwiftUI

struct RolePickerView: View {
    let session: FleetSession
    @EnvironmentObject var vm: FleetViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Role for \(session.project)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

            Divider().background(Color.white.opacity(0.08))

            // Role list
            ForEach(FleetRole.all) { role in
                Button(action: {
                    vm.setRole(for: session, role: role.id)
                    dismiss()
                }) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(session.role == role.id
                                  ? Color(hex: "#00d4ff")
                                  : Color.white.opacity(0.15))
                            .frame(width: 7, height: 7)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(role.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Text(role.description)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(session.role == role.id
                                ? Color.white.opacity(0.05)
                                : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().background(Color.white.opacity(0.05))
            }

            // Set for whole project
            Button(action: {
                vm.setRoleForProject(session.project, role: session.role)
                dismiss()
            }) {
                Text("Apply current role to all \(session.project) sessions")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#00d4ff").opacity(0.65))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 300)
        .background(Color(hex: "#0d1528"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
