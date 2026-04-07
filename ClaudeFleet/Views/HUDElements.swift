import SwiftUI

// MARK: - Dot grid background (kept for compat)
struct DotGridBackground: View {
    var body: some View { LineGridBackground() }
}

// MARK: - Line grid background (matches HTML prototype)
struct LineGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 28
            var p = Path()
            // Vertical lines
            var x: CGFloat = 0
            while x <= size.width {
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            // Horizontal lines
            var y: CGFloat = 0
            while y <= size.height {
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(p, with: .color(Color(hex: "#00d4ff").opacity(0.08)), lineWidth: 0.5)
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
                                .init(color: Color(hex: "#00d4ff").opacity(0.12), location: 0.3),
                                .init(color: Color(hex: "#00d4ff").opacity(0.40), location: 0.5),
                                .init(color: Color(hex: "#00d4ff").opacity(0.12), location: 0.7),
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
        Path { path in
            let r: CGFloat = 6  // corner radius
            path.move(to: CGPoint(x: 0, y: size))
            path.addLine(to: CGPoint(x: 0, y: r))
            path.addQuadCurve(to: CGPoint(x: r, y: 0), control: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: size, y: 0))
        }
        .stroke(color, lineWidth: thickness)
        .frame(width: size, height: size)
        .padding(6)
    }
}

// MARK: - Animated pending border (chasing gradient — matches HTML border-chase)

struct PendingBorderModifier: ViewModifier {
    let cornerRadius: CGFloat
    var color: Color = Color(hex: "#00d4ff")

    func body(content: Content) -> some View {
        content.overlay(
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let p = CGFloat(t.truncatingRemainder(dividingBy: 5.0) / 5.0)  // 5s cycle (was 2s)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(lineWidth: 1)
                    .foregroundStyle(
                        AngularGradient(
                            stops: [
                                .init(color: color.opacity(0.0),  location: max(0, p - 0.12)),
                                .init(color: color.opacity(0.55), location: p),
                                .init(color: color.opacity(0.0),  location: min(1, p + 0.12)),
                            ],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        )
                    )
            }
        )
    }
}

extension View {
    func pendingBorder(cornerRadius: CGFloat = 14, color: Color = Color(hex: "#00d4ff")) -> some View {
        modifier(PendingBorderModifier(cornerRadius: cornerRadius, color: color))
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
