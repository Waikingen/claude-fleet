import SwiftUI

struct ConfigView: View {
    @StateObject private var cfg = ConfigViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            Color(hex: "#070c1a").opacity(0.75).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Settings")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    if cfg.savedIndicator {
                        Text("Saved")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(hex: "#34d399"))
                            .transition(.opacity)
                    }
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.07))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                Divider().background(Color.white.opacity(0.07))

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        // Prompt editor
                        configSection("Haiku Analysis Prompt") {
                            ZStack(alignment: .topLeading) {
                                if cfg.analyzePrompt.isEmpty {
                                    Text("Prompt will be loaded from fleet.py on next scan…")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.2))
                                        .padding(10)
                                }
                                TextEditor(text: $cfg.analyzePrompt)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.75))
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .frame(minHeight: 220)
                                    .onChange(of: cfg.analyzePrompt) { _ in cfg.scheduleSave() }
                            }
                            .padding(10)
                            .background(Color.black.opacity(0.25))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 1))
                            .cornerRadius(8)

                            Button("Reset to default") {
                                cfg.resetToDefault()
                            }
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.3))
                            .buttonStyle(.plain)
                        }

                        // Parameters
                        configSection("Analysis Parameters") {
                            VStack(spacing: 14) {
                                paramRow("Confidence threshold") {
                                    HStack(spacing: 10) {
                                        Slider(value: $cfg.confidenceThreshold, in: 0.5...1.0, step: 0.05)
                                            .tint(Color(hex: "#00d4ff"))
                                            .onChange(of: cfg.confidenceThreshold) { _ in cfg.scheduleSave() }
                                        Text(String(format: "%.0f%%", cfg.confidenceThreshold * 100))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(Color(hex: "#00d4ff"))
                                            .frame(width: 36, alignment: .trailing)
                                    }
                                }

                                paramRow("Analysis timeout (s)") {
                                    Stepper("\(cfg.analysisTimeoutSecs)s",
                                            value: $cfg.analysisTimeoutSecs, in: 5...60, step: 5)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.6))
                                        .onChange(of: cfg.analysisTimeoutSecs) { _ in cfg.scheduleSave() }
                                }

                                paramRow("Max parallel analyses") {
                                    Stepper("\(cfg.maxParallelAnalyses)",
                                            value: $cfg.maxParallelAnalyses, in: 1...12, step: 1)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.6))
                                        .onChange(of: cfg.maxParallelAnalyses) { _ in cfg.scheduleSave() }
                                }
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 560, height: 600)
    }

    @ViewBuilder
    private func configSection<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.25))
                .tracking(0.8)
                .textCase(.uppercase)
            content()
        }
    }

    @ViewBuilder
    private func paramRow<Content: View>(_ label: String, @ViewBuilder control: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            control()
                .frame(maxWidth: 220)
        }
        .padding(.vertical, 2)
    }
}
