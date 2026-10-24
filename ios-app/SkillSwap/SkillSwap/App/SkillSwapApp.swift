import SwiftUI
import Combine

@main
struct SkillSwapApp: App {
    @StateObject private var session = AuthSession()
    @StateObject private var model = AppModel()
    @StateObject private var config = AppConfig.shared

    init() {
        // Runs before any screen is built, so Firebase is ready when AuthSession is created.
        FirebaseBootstrap.configureIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(model)
                .environmentObject(config)
                .onAppear {
                    let s = session
                    API.shared.tokenProvider = { try await s.token() }
                }
        }
    }
}

/// What the whole app shares: the signed-in student's profile.
@MainActor
final class AppModel: ObservableObject {
    @Published var me: UserProfile?
    @Published var isLoading = false
    @Published var loadError: String?

    func loadMe() async {
        isLoading = true
        loadError = nil
        do {
            let fresh: UserProfile = try await API.shared.get("/api/me")
            me = fresh
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    func reset() {
        me = nil
        loadError = nil
    }
}
