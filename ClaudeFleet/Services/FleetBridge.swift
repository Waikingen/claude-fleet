import Foundation
import Combine

// MARK: - FleetBridge
// Reads ~/.claude-fleet/state.json via FSEvents.
// Commands (approve/deny/scan) go through FleetSocket.

final class FleetBridge: @unchecked Sendable {
    static let shared = FleetBridge()

    private let fleetDir  = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude-fleet")
    private var stateFile: URL { fleetDir.appendingPathComponent("state.json") }

    private var fsEventStream: FSEventStreamRef?
    private let stateChangeSubject = PassthroughSubject<FleetState, Never>()

    var stateChanges: AnyPublisher<FleetState, Never> {
        stateChangeSubject.eraseToAnyPublisher()
    }

    func loadState() -> FleetState {
        guard let data = try? Data(contentsOf: stateFile) else { return .empty }
        return (try? JSONDecoder().decode(FleetState.self, from: data)) ?? .empty
    }

    func startWatching(onChange: @escaping () -> Void) {
        let pathsToWatch = [fleetDir.path] as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )
        fsEventStream = FSEventStreamCreate(
            nil,
            { _, info, _, _, _, _ in
                guard let info = info else { return }
                let bridge = Unmanaged<FleetBridge>.fromOpaque(info).takeUnretainedValue()
                DispatchQueue.main.async {
                    bridge.stateChangeSubject.send(bridge.loadState())
                }
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        )
        if let stream = fsEventStream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
        }
    }

    func stopWatching() {
        guard let stream = fsEventStream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        fsEventStream = nil
    }
}
