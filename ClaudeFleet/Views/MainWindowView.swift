import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var vm: FleetViewModel
    @State private var showConfig = false

    var body: some View {
        ZStack {
            // Blur layer — real window blur behind content
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            // Navy tint — dark glass, still lets blur bleed through
            Color(hex: "#070c1a").opacity(0.72)
                .ignoresSafeArea()

            // Specular top edge — the signature liquid glass highlight
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.13), location: 0),
                    .init(color: .white.opacity(0.04), location: 0.015),
                    .init(color: .clear, location: 0.07),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Cyan ambient glow from top
            VStack {
                RadialGradient(
                    colors: [Color(hex: "#00d4ff").opacity(0.07), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 500
                )
                .frame(height: 500)
                Spacer()
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                TopBarView(showConfig: $showConfig)
                    .environmentObject(vm)

                Divider()
                    .background(Color.white.opacity(0.06))

                Group {
                    if let focused = vm.focusedSession {
                        AgentFocusView(session: focused)
                            .environmentObject(vm)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        HStack(spacing: 0) {
                            ZStack {
                                LineGridBackground()
                                    .contentShape(Rectangle())
                                    .onTapGesture { NSApp.keyWindow?.orderOut(nil) }
                                FleetScrollView {
                                    SessionsGridView()
                                        .environmentObject(vm)
                                        .padding(20)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .clipped()

                            Divider().background(Color.white.opacity(0.06))

                            DetailSidebarView()
                                .environmentObject(vm)
                                .frame(width: 440)
                        }
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Status bar
                Divider()
                    .background(Color.white.opacity(0.05))
                StatusBarView()
                    .environmentObject(vm)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = vm.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 44)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3), value: vm.toast?.id)
            }
        }
        .sheet(isPresented: $showConfig) { ConfigView().environmentObject(vm) }
        // Key handling lives in AppDelegate's local event monitor (panel is non-activating)
    }
}
