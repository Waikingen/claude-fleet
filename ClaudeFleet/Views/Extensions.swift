import SwiftUI
import AppKit

// MARK: - Color hex init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:     Double(r) / 255,
            green:   Double(g) / 255,
            blue:    Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Pulsing dot modifier

struct PulsingModifier: ViewModifier {
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    scale = 0.7
                }
            }
    }
}

extension View {
    func pulsing() -> some View {
        modifier(PulsingModifier())
    }

    @ViewBuilder
    func ifCondition(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - Custom thin scrollbar (replaces ugly default macOS scrollbars)

struct FleetScrollView<Content: View>: View {
    let content: Content
    @State private var contentHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var isHovered = false
    @State private var isDragging = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var canScroll: Bool { contentHeight > viewportHeight && viewportHeight > 0 }
    private var thumbHeight: CGFloat {
        guard canScroll else { return 0 }
        return max(30, viewportHeight * (viewportHeight / contentHeight))
    }
    private var thumbOffset: CGFloat {
        guard canScroll else { return 0 }
        let scrollable = contentHeight - viewportHeight
        let trackSpace = viewportHeight - thumbHeight
        guard scrollable > 0 else { return 0 }
        return (scrollOffset / scrollable) * trackSpace
    }

    var body: some View {
        GeometryReader { outerGeo in
            ZStack(alignment: .topTrailing) {
                ScrollView(.vertical, showsIndicators: false) {
                    content
                        .background(
                            GeometryReader { innerGeo in
                                Color.clear
                                    .preference(key: ScrollOffsetKey.self,
                                                value: -innerGeo.frame(in: .named("fleetScroll")).origin.y)
                                    .preference(key: ContentHeightKey.self,
                                                value: innerGeo.size.height)
                            }
                        )
                }
                .coordinateSpace(name: "fleetScroll")
                .onPreferenceChange(ScrollOffsetKey.self) { scrollOffset = max(0, $0) }
                .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }

                // Custom scrollbar thumb
                if canScroll {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "#00d4ff").opacity(isHovered || isDragging ? 0.35 : 0.12))
                        .frame(width: isDragging ? 5 : 3, height: thumbHeight)
                        .offset(y: thumbOffset)
                        .padding(.trailing, 2)
                        .padding(.top, 2)
                        .animation(.easeOut(duration: 0.15), value: isHovered)
                        .animation(.easeOut(duration: 0.15), value: isDragging)
                        .opacity(isHovered || isDragging || scrollOffset > 0 ? 1 : 0)
                }
            }
            .onHover { isHovered = $0 }
            .onAppear { viewportHeight = outerGeo.size.height }
            .onChange(of: outerGeo.size.height) { _, h in viewportHeight = h }
        }
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Visual effect blur (NSVisualEffectView wrapper)

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        // Force dark appearance so blur layer is always dark, regardless of desktop color
        v.appearance = NSAppearance(named: .vibrantDark)
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blendingMode
    }
}
