import Foundation
import FirebaseCore

/// How the app signs in.
/// dev      = no Firebase. You type a name. Use it for the very first test (backend AUTH_MODE=dev).
/// firebase = real Firebase sign-in (backend AUTH_MODE=firebase). Needs GoogleService-Info.plist.
enum AuthMode: String, CaseIterable, Identifiable {
    case dev
    case firebase
    var id: String { rawValue }
    var title: String { self == .dev ? "Dev (no Firebase)" : "Firebase" }
}

/// Settings the user can change inside the app (Settings screen), kept on the device.
final class AppConfig: ObservableObject {
    static let shared = AppConfig()

    /// The simulator reaches the Mac at 127.0.0.1. A real iPhone needs the Mac's Wi-Fi address,
    /// for example http://192.168.1.23:5000 (change it in the app's Settings, no rebuild needed).
    static let defaultBaseURL = "http://127.0.0.1:5001"
    static let defaultAuthMode: AuthMode = .dev

    @Published var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: "baseURL") }
    }
    @Published var authMode: AuthMode {
        didSet { UserDefaults.standard.set(authMode.rawValue, forKey: "authMode") }
    }

    private init() {
        let savedURL = UserDefaults.standard.string(forKey: "baseURL")
        if let saved = savedURL, saved != "http://127.0.0.1:5000" {
            baseURL = saved
        } else {
            baseURL = AppConfig.defaultBaseURL
        }
        let saved = UserDefaults.standard.string(forKey: "authMode") ?? ""
        authMode = AuthMode(rawValue: saved) ?? AppConfig.defaultAuthMode
    }
}

/// Starts Firebase once, and only in firebase mode, so dev mode works before Firebase is set up.
enum FirebaseBootstrap {
    static var isReady = false

    static func configureIfNeeded() {
        guard AppConfig.shared.authMode == .firebase else { return }
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        isReady = true
    }
}
