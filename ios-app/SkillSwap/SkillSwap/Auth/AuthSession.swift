import Foundation
import FirebaseAuth
import SwiftUI
import Combine

/// Who is signed in. In firebase mode this wraps Firebase Auth; in dev mode it just remembers a name.
@MainActor
final class AuthSession: ObservableObject {
    enum State {
        case loading
        case signedOut
        case signedIn
    }

    @Published var state: State = .loading
    @Published var setupProblem: String?

    private var handle: AuthStateDidChangeListenerHandle?
    private var devToken: String?

    init() {
        if AppConfig.shared.authMode == .dev {
            if let saved = UserDefaults.standard.string(forKey: "devToken") {
                devToken = saved
                state = .signedIn
            } else {
                state = .signedOut
            }
            return
        }
        guard FirebaseBootstrap.isReady else {
            setupProblem = "GoogleService-Info.plist is not in the app. Add it (docs/02_FIREBASE_SETUP.md), or switch to Dev mode in Settings."
            state = .signedOut
            return
        }
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.state = (user == nil) ? .signedOut : .signedIn
            }
        }
    }

    /// The token the backend checks on every request.
    func token() async throws -> String {
        if AppConfig.shared.authMode == .dev {
            guard let devToken = devToken else { throw APIError(message: "Please sign in.") }
            return devToken
        }
        guard let user = Auth.auth().currentUser else { throw APIError(message: "Please sign in.") }
        return try await user.getIDToken()
    }

    // MARK: sign in / up

    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signUp(email: String, password: String) async throws {
        _ = try await Auth.auth().createUser(withEmail: email, password: password)
    }

    func devSignIn(name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let uid = String(clean.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) })
        // HTTP headers must be plain ASCII; the real name is saved through PUT /api/me afterwards.
        let asciiName = String(clean.unicodeScalars.filter { $0.isASCII })
        let token = "dev:\(uid.isEmpty ? "student" : uid):\(asciiName.isEmpty ? "Student" : asciiName)"
        devToken = token
        UserDefaults.standard.set(token, forKey: "devToken")
        state = .signedIn
    }

    /// Dev mode only: sign in as one of the seeded demo students (token dev:demo_aditi ...).
    func devSignInRaw(token: String) {
        devToken = token
        UserDefaults.standard.set(token, forKey: "devToken")
        state = .signedIn
    }

    func signOut() {
        if AppConfig.shared.authMode == .dev {
            devToken = nil
            UserDefaults.standard.removeObject(forKey: "devToken")
        } else {
            try? Auth.auth().signOut()
        }
        state = .signedOut
    }
}
