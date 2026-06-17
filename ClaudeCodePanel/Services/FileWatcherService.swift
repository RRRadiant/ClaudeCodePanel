import Foundation

final class FileWatcherService: @unchecked Sendable {
    static let shared = FileWatcherService()

    private var sources: [DispatchSourceFileSystemObject] = []

    func watch(path: String, onChange: @escaping () -> Void) {
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
        sources.append(source)
    }

    func stopAll() {
        for source in sources {
            source.cancel()
        }
        sources.removeAll()
    }
}
