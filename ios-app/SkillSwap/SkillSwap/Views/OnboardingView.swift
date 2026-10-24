import SwiftUI
import UniformTypeIdentifiers

/// First screen for a new student: upload a resume and the AI builds the skill profile.
struct OnboardingView: View {
    @EnvironmentObject var app: AppModel
    let skip: () -> Void

    private var greeting: String {
        if let me = app.me { return "Welcome, \(me.name)!" }
        return "Welcome!"
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass").font(.system(size: 56)).foregroundColor(.blue)
            Text(greeting).font(.title.bold())
            Text("Upload your resume (PDF). We read your skills and projects so we can suggest the right teams and teammates.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            ResumeUploader()
            Button("Skip for now", action: skip).foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
}

/// PDF picker + "paste text" fallback. Used on onboarding and on the profile screen.
struct ResumeUploader: View {
    @EnvironmentObject var app: AppModel
    @State private var picking = false
    @State private var pasting = false
    @State private var pastedText = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        VStack(spacing: 10) {
            if busy {
                ProgressView("Reading your resume... (up to a minute)")
            } else {
                Button { picking = true } label: {
                    Label("Choose resume PDF", systemImage: "arrow.up.doc").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button("Paste resume text instead") { pasting = true }
            }
            ErrorBanner(message: error)
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: [UTType.pdf]) { result in
            handle(result)
        }
        .sheet(isPresented: $pasting) {
            NavigationStack {
                VStack {
                    TextEditor(text: $pastedText)
                        .border(Color.gray.opacity(0.3))
                        .padding()
                }
                .navigationTitle("Paste resume")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { pasting = false } }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Read it") {
                            pasting = false
                            sendText()
                        }
                        .disabled(pastedText.count < 60)
                    }
                }
            }
        }
    }

    private func handle(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let err):
            error = err.localizedDescription
        case .success(let url):
            attempt($error, busy: $busy) {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                let updated: UserProfile = try await API.shared.upload(
                    "/api/me/resume", fileData: data, fileName: url.lastPathComponent, mime: "application/pdf")
                app.me = updated
            }
        }
    }

    private func sendText() {
        attempt($error, busy: $busy) {
            let updated: UserProfile = try await API.shared.post(
                "/api/me/resume", body: ["text": pastedText], timeout: 120)
            app.me = updated
        }
    }
}
