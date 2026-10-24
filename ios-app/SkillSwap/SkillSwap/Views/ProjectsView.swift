import SwiftUI

struct ProjectsView: View {
    @State private var scope = "mine"
    @State private var projects: [ProjectSummary] = []
    @State private var error: String?
    @State private var creating = false
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            List {
                Picker("Show", selection: $scope) {
                    Text("My projects").tag("mine")
                    Text("Open projects").tag("open")
                }
                .pickerStyle(.segmented)

                if error != nil {
                    ErrorBanner(message: error)
                }
                if projects.isEmpty && loaded && error == nil {
                    Text(scope == "mine" ? "You are not in a project yet. Tap + to start one." : "No open projects right now.")
                        .foregroundColor(.secondary)
                }
                ForEach(projects) { project in
                    NavigationLink(destination: ProjectDetailView(projectId: project.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(project.title).font(.headline)
                                if project.status == "completed" { Pill(text: "Completed", color: .green) }
                            }
                            Text("Leader: \(project.leaderName) · \(project.members) member\(project.members == 1 ? "" : "s")")
                                .font(.caption).foregroundColor(.secondary)
                            if project.milestonesTotal > 0 {
                                Text("\(project.milestonesDone)/\(project.milestonesTotal) milestones done")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            if !project.openNeeds.isEmpty {
                                Text("Looking for: " + project.openNeeds.joined(separator: ", "))
                                    .font(.caption).foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { creating = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $creating, onDismiss: { Task { await load() } }) {
                CreateProjectView()
            }
            .refreshable { await load() }
            .task(id: scope) { await load() }
        }
    }

    private func load() async {
        do {
            let response: ProjectsResponse = try await API.shared.get("/api/projects", query: ["scope": scope])
            projects = response.projects
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }
}
