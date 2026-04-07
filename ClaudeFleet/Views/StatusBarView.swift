import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject var vm: FleetViewModel

    var lastScanLabel: String {
        guard let date = vm.lastScanDate else { return "Not scanned yet" }
        let secs = Int(-date.timeIntervalSinceNow)
        if secs < 5  { return "Last scan: just now" }
        if secs < 60 { return "Last scan: \(secs)s ago" }
        return "Last scan: \(secs / 60)m ago"
    }

    var body: some View {
        HStack(spacing: 14) {
            // Live indicator
            HStack(spacing: 5) {
                RadarPulse(color: Color(hex: "#00d4ff"))
                    .frame(width: 5, height: 5)
                Text("Connected to iTerm2")
                    .font(.system(size: 10.5))
                    .foregroundColor(.white.opacity(0.22))
            }

            Text("·")
                .foregroundColor(.white.opacity(0.15))

            Text("Mode: \(vm.mode.label)")
                .font(.system(size: 10.5))
                .foregroundColor(.white.opacity(0.22))

            Text("·")
                .foregroundColor(.white.opacity(0.15))

            Text(lastScanLabel)
                .font(.system(size: 10.5))
                .foregroundColor(.white.opacity(0.22))

            Spacer()

            // Keyboard hints
            HStack(spacing: 6) {
                KeyHint("↵") { Text("approve") }
                KeyHint("⌫") { Text("deny") }
                KeyHint("⌘↵") { Text("approve all") }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 30)
        .background(Color.clear)
    }
}

struct KeyHint<Label: View>: View {
    let key: String
    let label: () -> Label

    init(_ key: String, @ViewBuilder label: @escaping () -> Label) {
        self.key = key
        self.label = label
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(3)
            label()
                .font(.system(size: 10.5))
                .foregroundColor(.white.opacity(0.18))
        }
    }
}
