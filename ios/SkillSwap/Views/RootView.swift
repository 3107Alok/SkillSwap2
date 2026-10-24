import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: AuthSession

    var body: some View {
        switch session.state {
        case .loading:
            ProgressView("Starting...")
        case .signedOut:
            AuthView()
        case .signedIn:
            SignedInGate()
        }
    }
}

/// After sign-in: load the profile; a new student is first asked for a resume.
struct SignedInGate: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var session: AuthSession
    @State private var skippedResume = false

    var body: some View {
        Group {
            if let me = app.me {
                if !me.hasResume && !skippedResume {
                    OnboardingView(skip: { skippedResume = true })
                } else {
                    MainTabView()
                }
            } else if let problem = app.loadError {
                VStack(spacing: 16) {
                    Text("Could not load your profile").font(.headline)
                    ErrorBanner(message: problem)
                    Button("Try again") { Task { await app.loadMe() } }
                        .buttonStyle(.borderedProminent)
                    Button("Sign out") {
                        session.signOut()
                        app.reset()
                    }
                }
                .padding()
            } else {
                ProgressView("Loading your profile...")
            }
        }
        .task { await app.loadMe() }
    }
}
