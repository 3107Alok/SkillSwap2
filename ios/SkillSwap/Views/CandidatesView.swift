import SwiftUI

/// The leader sees the best-fitting students for one open role, with the reason for each match.
struct CandidatesView: View {
    let projectId: String
    let need: NeedItem
    let onAdded: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var items: [MatchItem] = []
    @State private var error: String?
    @State private var busy = false
    @State private var loaded = false

    var body: some View {
        List {
            if error != nil { Section { ErrorBanner(message: error) } }
            if items.isEmpty && loaded && error == nil {
                Text("No suitable students yet. Others may still sign up; check again later.")
                    .foregroundColor(.secondary)
            }
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 8) {
                    NavigationLink(destination: UserDetailView(uid: item.uid)) {
                        MatchCard(item: item)
                    }
                    Button("Add to project as \(need.role)") { add(item) }
                        .buttonStyle(.borderedProminent)
                        .disabled(busy)
                }
            }
        }
        .navigationTitle(need.role)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        do {
            let response: CandidatesResponse = try await API.shared.get(
                "/api/projects/\(projectId)/needs/\(need.index)/candidates")
            items = response.results
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }

    private func add(_ item: MatchItem) {
        attempt($error, busy: $busy) {
            let _: ProjectDetail = try await API.shared.post(
                "/api/projects/\(projectId)/members", body: ["uid": item.uid, "need_index": need.index])
            onAdded()
            dismiss()
        }
    }
}

/// Students who applied; the leader accepts or declines.
struct RequestsView: View {
    let projectId: String
    let onChanged: () -> Void

    @State private var requests: [JoinRequest] = []
    @State private var error: String?
    @State private var busy = false
    @State private var loaded = false

    var body: some View {
        List {
            if error != nil { Section { ErrorBanner(message: error) } }
            if requests.isEmpty && loaded && error == nil {
                Text("No applications right now.").foregroundColor(.secondary)
            }
            ForEach(requests) { request in
                VStack(alignment: .leading, spacing: 8) {
                    NavigationLink(destination: UserDetailView(uid: request.user.uid)) {
                        HStack(spacing: 10) {
                            AvatarView(path: request.user.avatarUrl)
                            VStack(alignment: .leading) {
                                Text(request.user.name).font(.headline)
                                Text(request.role.isEmpty ? "Wants to join" : "Applied for: \(request.role)")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    if !request.message.isEmpty { Text("\"\(request.message)\"").font(.footnote) }
                    HStack {
                        Button("Accept") { decide(request, "accept") }.buttonStyle(.borderedProminent)
                        Button("Decline") { decide(request, "decline") }.buttonStyle(.bordered)
                    }
                    .disabled(busy)
                }
            }
        }
        .navigationTitle("Join requests")
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        do {
            let response: RequestsResponse = try await API.shared.get("/api/projects/\(projectId)/requests")
            requests = response.requests
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }

    private func decide(_ request: JoinRequest, _ decision: String) {
        attempt($error, busy: $busy) {
            let _: ProjectDetail = try await API.shared.post(
                "/api/projects/\(projectId)/requests/\(request.user.uid)/\(decision)")
            onChanged()
            await load()
        }
    }
}
