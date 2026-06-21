import Foundation

final class FileWatcherService: @unchecked Sendable {
    static let shared = FileWatcherService()

    /// Per-path dispatch sources — prevents duplicate watches and fd leaks.
    private var sources: [String: DispatchSourceFileSystemObject] = [:]

    func watch(path: String, onChange: @escaping () -> Void) {
        // Dedup: if already watching this path, cancel old source first
        if let existing = sources[path] {
            existing.cancel()
        }

        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler {
            onChange()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        sources[path] = source
    }

    func stopWatching(path: String) {
        sources[path]?.cancel()
        sources[path] = nil
    }

    func stopAll() {
        for (_, source) in sources {
            source.cancel()
        }
        sources.removeAll()
    }
}
