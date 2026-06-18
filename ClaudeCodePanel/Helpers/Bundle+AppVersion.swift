import Foundation

extension Bundle {
    /// The app's short version string (e.g. "1.9") from Info.plist.
    static var appVersion: String {
        main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    /// Optional variant returning nil when the key is absent.
    static var appVersionOrNil: String? {
        main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
}
