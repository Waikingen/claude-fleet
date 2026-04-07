import Foundation
import Combine

@MainActor
final class ConfigViewModel: ObservableObject {
    private let configPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude-fleet/config.json")
    private let promptPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude-fleet/analyze_prompt.txt")

    @Published var analyzePrompt: String = ""
    @Published var confidenceThreshold: Double = 0.80
    @Published var analysisTimeoutSecs: Int = 15
    @Published var maxParallelAnalyses: Int = 6
    @Published var savedIndicator: Bool = false

    private var saveTask: Task<Void, Never>?

    init() { load() }

    func load() {
        if let text = try? String(contentsOf: promptPath, encoding: .utf8), !text.isEmpty {
            analyzePrompt = text
        }
        guard let data = try? Data(contentsOf: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if let v = json["confidence_threshold"] as? Double { confidenceThreshold = v }
        if let v = json["analysis_timeout_secs"] as? Int { analysisTimeoutSecs = v }
        if let v = json["max_parallel_analyses"] as? Int { maxParallelAnalyses = v }
    }

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    func save() {
        try? analyzePrompt.write(to: promptPath, atomically: true, encoding: .utf8)

        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: configPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }
        json["confidence_threshold"]  = confidenceThreshold
        json["analysis_timeout_secs"] = analysisTimeoutSecs
        json["max_parallel_analyses"] = maxParallelAnalyses

        if let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            try? data.write(to: configPath)
        }

        savedIndicator = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self?.savedIndicator = false
        }
    }

    func resetToDefault() {
        try? FileManager.default.removeItem(at: promptPath)
        // Re-load will show empty; user must scan once to regenerate default
        analyzePrompt = ""
    }
}
