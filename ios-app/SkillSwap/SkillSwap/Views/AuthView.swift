import SwiftUI

struct AuthView: View {
    @EnvironmentObject var session: AuthSession
    @EnvironmentObject var config: AppConfig
    @EnvironmentObject var app: AppModel

    @State private var creating = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var gender = "unspecified"
    @State private var error: String?
    @State private var busy = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SkillSwap").font(.largeTitle.bold())
                        Text("Find teammates who complement your skills, and build a reputation in every domain.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                if config.authMode == .dev {
                    devSection
                } else {
                    firebaseSection
                }

                if let problem = session.setupProblem {
                    Section { ErrorBanner(message: problem) }
                }
                if error != nil {
                    Section { ErrorBanner(message: error) }
                }
            }
            .navigationTitle(config.authMode == .dev ? "Dev sign-in" : (creating ? "Create account" : "Sign in"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    // MARK: dev mode (no Firebase)

    private var devSection: some View {
        Group {
            Section(header: Text("Your name"), footer: Text("Dev mode: no password. Use it only to test before Firebase is set up.")) {
                TextField("Name", text: $name)
                Picker("Avatar", selection: $gender) { genderOptions }
            }
            Section {
                Button("Continue") {
                    attempt($error, busy: $busy) {
                        session.devSignIn(name: name)
                        let _: UserProfile = try await API.shared.put("/api/me", body: ["name": name, "gender": gender])
                        await app.loadMe()
                    }
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).count < 2 || busy)
            }
            Section(header: Text("Demo students (after running seed.sh)")) {
                ForEach(["demo_aditi", "demo_meera", "demo_ananya", "demo_rohan"], id: \.self) { uid in
                    Button("Sign in as \(uid)") { session.devSignInRaw(token: "dev:\(uid)") }
                }
            }
        }
    }

    // MARK: firebase mode

    private var firebaseSection: some View {
        Group {
            Section {
                Picker("", selection: $creating) {
                    Text("Sign in").tag(false)
                    Text("Create account").tag(true)
                }
                .pickerStyle(.segmented)
            }
            Section {
                if creating {
                    TextField("Full name", text: $name)
                        .textContentType(.name)
                    Picker("Avatar", selection: $gender) { genderOptions }
                }
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                SecureField("Password (6+ characters)", text: $password)
            }
            Section(footer: Text(creating ? "Gender is optional and only picks your avatar." : "")) {
                Button(creating ? "Create account" : "Sign in") { submit() }
                    .disabled(!canSubmit || busy)
            }
        }
    }

    private var genderOptions: some View {
        Group {
            Text("Prefer not to say").tag("unspecified")
            Text("Female").tag("female")
            Text("Male").tag("male")
            Text("Other").tag("other")
        }
    }

    private var canSubmit: Bool {
        let okBasics = email.contains("@") && password.count >= 6
        return creating ? (okBasics && name.trimmingCharacters(in: .whitespaces).count >= 2) : okBasics
    }

    private func submit() {
        attempt($error, busy: $busy) {
            if creating {
                try await session.signUp(email: email, password: password)
                // The account exists now: save the chosen name and avatar on the server.
                let _: UserProfile = try await API.shared.put("/api/me", body: ["name": name, "gender": gender])
                await app.loadMe()
            } else {
                try await session.signIn(email: email, password: password)
            }
        }
    }
}
