import SwiftUI

// MARK: - Dot grid background

struct DotGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 26
            let r: CGFloat = 1.0
            for xi in stride(from: CGFloat(0), through: size.width, by: spacing) {
                for yi in stride(from: CGFloat(0), through: size.height, by: spacing) {
                    context.opacity = 0.09
                    context.fill(
                        Path(ellipseIn: CGRect(x: xi - r, y: yi - r, width: r * 2, height: r * 2)),
                        with: .color(.white)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Scan beam (shown while scanning)

struct ScanBeamView: View {
    @State private var yOffset: CGFloat = -80

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Beam glow
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: Color(hex: "#00d4ff").opacity(0.08), location: 0.3),
                                .init(color: Color(hex: "#00d4ff").opacity(0.30), location: 0.5),
                                .init(color: Color(hex: "#00d4ff").opacity(0.08), location: 0.7),
                                .init(color: .clear, location: 1.0),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 80)
                    .offset(y: yOffset)

                // Hard line
                Rectangle()
                    .fill(Color(hex: "#00d4ff").opacity(0.55))
                    .frame(height: 1)
                    .offset(y: yOffset + 40)
            }
            .frame(maxWidth: .infinity)
            .clipped()
            .onAppear {
                yOffset = -80
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    yOffset = geo.size.height + 80
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - HUD corner brackets

struct HUDCorners: View {
    var size: CGFloat = 18
    var thickness: CGFloat = 1.5
    var color: Color = Color(hex: "#00d4ff").opacity(0.45)

    var body: some View {
        ZStack {
            // Top-left
            corner().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // Top-right
            corner().rotationEffect(.degrees(90)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            // Bottom-left
            corner().rotationEffect(.degrees(270)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            // Bottom-right
            corner().rotationEffect(.degrees(180)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .allowsHitTesting(false)
    }

    private func corner() -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(color)
                .frame(width: size, height: thickness)
            Rectangle()
                .fill(color)
                .frame(width: thickness, height: size)
        }
        .padding(6)
    }
}

// MARK: - Animated pending border (pulsing cyan on cards awaiting review)

struct PendingBorderModifier: ViewModifier {
    @State private var pulse = false
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    Color(hex: "#00d4ff").opacity(pulse ? 0.65 : 0.18),
                    lineWidth: pulse ? 1.5 : 0.8
                )
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
        )
        .onAppear { pulse = true }
    }
}

extension View {
    func pendingBorder(cornerRadius: CGFloat = 14) -> some View {
        modifier(PendingBorderModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Radar pulse (for status indicator)

struct RadarPulse: View {
    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 0.7
    var color: Color = Color(hex: "#00d4ff")

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(opacity), lineWidth: 1)
                .scaleEffect(scale)
                .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: scale)
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
                .shadow(color: color.opacity(0.8), radius: 4)
        }
        .frame(width: 5, height: 5)
        .onAppear {
            scale = 3.5
            opacity = 0
        }
    }
}
