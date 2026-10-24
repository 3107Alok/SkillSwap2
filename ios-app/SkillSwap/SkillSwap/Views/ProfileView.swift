import SwiftUI

/// Your own profile: edit name / avatar, upload a new resume, see reputation, sign out.
struct ProfileView: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var session: AuthSession
    @State private var editing = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let me = app.me {
                        ProfileContent(user: me)
                        Divider()
                        Text(me.hasResume ? "Update your resume" : "Add your resume").font(.headline)
                        ResumeUploader()
                        ForEach(me.warnings, id: \.self) { Text($0).font(.footnote).foregroundColor(.orange) }
                        Divider()
                        Button("Sign out", role: .destructive) {
                            session.signOut()
                            app.reset()
                        }
                    } else {
                        ProgressView()
                    }
                }
                .padding()
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") { editing = true }
                }
            }
            .sheet(isPresented: $editing) { EditProfileView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .refreshable { await app.loadMe() }
        }
    }
}

struct EditProfileView: View {
    @EnvironmentObject var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var gender = "unspecified"
    @State private var available = true
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Name")) { TextField("Your name", text: $name) }
                Section(header: Text("Avatar"), footer: Text("Optional. Only used to pick your avatar picture, never for matching.")) {
                    Picker("Gender", selection: $gender) {
                        Text("Prefer not to say").tag("unspecified")
                        Text("Female").tag("female")
                        Text("Male").tag("male")
                        Text("Other").tag("other")
                    }
                }
                Section(footer: Text("Turn off when you are fully booked; you will not appear in suggestions.")) {
                    Toggle("Open to new projects", isOn: $available)
                }
                if error != nil { Section { ErrorBanner(message: error) } }
            }
            .navigationTitle("Edit profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }.disabled(busy || name.trimmingCharacters(in: .whitespaces).count < 2)
                }
            }
            .onAppear {
                if let me = app.me {
                    name = me.name
                    gender = me.gender
                    available = me.available
                }
            }
        }
    }

    private func save() {
        attempt($error, busy: $busy) {
            let updated: UserProfile = try await API.shared.put(
                "/api/me", body: ["name": name, "gender": gender, "available": available])
            app.me = updated
            dismiss()
        }
    }
}

/// Another student's public profile (from a team, a search or a match).
struct UserDetailView: View {
    let uid: String
    @State private var user: UserProfile?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ErrorBanner(message: error)
                if let user = user {
                    ProfileContent(user: user)
                } else if error == nil {
                    ProgressView()
                }
            }
            .padding()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                let fetched: UserProfile = try await API.shared.get("/api/users/\(uid)")
                user = fetched
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

/// The shared profile layout: who they are, leader tags, reputation per domain, skills, projects.
struct ProfileContent: View {
    let user: UserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                AvatarView(path: user.avatarUrl, size: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name).font(.title2.bold())
                    if !user.headline.isEmpty { Text(user.headline).font(.subheadline).foregroundColor(.secondary) }
                    if !user.education.isEmpty { Text(user.education).font(.caption).foregroundColor(.secondary) }
                    if !user.available { Pill(text: "Fully booked", color: .orange) }
                }
            }

            ForEach(user.leaderTags, id: \.self) { tag in
                Pill(text: "Project leader: \(tag)", color: .purple)
            }
            ForEach(user.leadHistory, id: \.self) { line in
                Text(line).font(.caption).foregroundColor(.secondary)
            }

            Text("Reputation by domain").font(.headline)
            if user.standings.isEmpty {
                Text("No reviewed tasks yet. Reputation grows as teammates and leaders mark finished work.")
                    .font(.footnote).foregroundColor(.secondary)
            }
            ForEach(user.standings) { standing in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(standing.domain).font(.subheadline.weight(.semibold))
                        Spacer()
                        Pill(text: standing.level, color: levelColor(standing.level))
                    }
                    if let reliability = standing.reliability {
                        ProgressView(value: reliability)
                    }
                    Text("\(standing.points) points · \(Fmt.percent(standing.reliability)) · \(standing.counted) reviewed task\(standing.counted == 1 ? "" : "s")")
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(10)
            }

            if !user.domains.isEmpty {
                Text("Domains").font(.headline)
                Text(user.domains.joined(separator: " · "))
            }
            if !user.skills.isEmpty {
                Text("Skills").font(.headline)
                ForEach(user.skills, id: \.self) { skill in
                    HStack {
                        Text(skill.name)
                        Spacer()
                        Text(skill.level).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            if !user.projects.isEmpty {
                Text("Projects").font(.headline)
                ForEach(user.projects, id: \.self) { project in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.title).font(.subheadline.weight(.semibold))
                        if !project.tech.isEmpty { Text(project.tech.joined(separator: ", ")).font(.caption).foregroundColor(.blue) }
                        if !project.summary.isEmpty { Text(project.summary).font(.footnote) }
                    }
                }
            }
        }
    }
}
