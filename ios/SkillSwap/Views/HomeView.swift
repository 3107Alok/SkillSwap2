import SwiftUI

/// "For you": open projects whose roles fit this student best, each with the reason why.
struct HomeView: View {
    @EnvironmentObject var app: AppModel
    @State private var items: [MatchItem] = []
    @State private var error: String?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            List {
                if let me = app.me, !me.hasResume {
                    Section {
                        Text("Upload your resume on the Profile tab to get matched.")
                            .foregroundColor(.orange)
                    }
                }
                if error != nil {
                    Section { ErrorBanner(message: error) }
                }
                Section(header: Text("Projects that fit you")) {
                    if items.isEmpty && loaded && error == nil {
                        Text("No open projects match yet. Check back soon, or start your own on the Projects tab.")
                            .foregroundColor(.secondary)
                    }
                    ForEach(items) { item in
                        if let projectId = item.projectId {
                            NavigationLink(destination: ProjectDetailView(projectId: projectId)) {
                                MatchCard(item: item, showsPerson: false)
                            }
                        }
                    }
                }
            }
            .navigationTitle("For you")
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        do {
            let response: MatchResponse = try await API.shared.get("/api/recommendations/projects")
            items = response.results
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }
}
