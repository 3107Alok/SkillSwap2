import SwiftUI

/// Team building for a hackathon: search students by domain (and optionally skills).
struct FindPeopleView: View {
    @State private var selected: Set<String> = []
    @State private var matchAll = false
    @State private var skills = ""
    @State private var results: [MatchItem] = []
    @State private var searched = false
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Pick the domains you need").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                        ForEach(Domains.all, id: \.self) { domain in
                            Button { toggle(domain) } label: {
                                Text(domain)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(selected.contains(domain) ? Color.blue : Color.gray.opacity(0.15))
                                    .foregroundColor(selected.contains(domain) ? .white : .primary)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Picker("Match", selection: $matchAll) {
                        Text("Any of these").tag(false)
                        Text("All of these").tag(true)
                    }
                    .pickerStyle(.segmented)
                    TextField("Skills (optional), e.g. Swift, Figma", text: $skills)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                    Button(busy ? "Searching..." : "Search") { search() }
                        .buttonStyle(.borderedProminent)
                        .disabled(busy || (selected.isEmpty && skills.trimmingCharacters(in: .whitespaces).isEmpty))
                    ErrorBanner(message: error)

                    if searched && results.isEmpty && error == nil && !busy {
                        Text("Nobody matches that yet.").foregroundColor(.secondary)
                    }
                    ForEach(results) { item in
                        NavigationLink(destination: UserDetailView(uid: item.uid)) {
                            MatchCard(item: item)
                                .padding(10)
                                .background(Color.gray.opacity(0.08))
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Find people")
        }
    }

    private func toggle(_ domain: String) {
        if selected.contains(domain) { selected.remove(domain) } else { selected.insert(domain) }
    }

    private func search() {
        var query: [String: String] = [
            "domains": Domains.all.filter { selected.contains($0) }.joined(separator: ","),
            "match": matchAll ? "all" : "any",
        ]
        let trimmed = skills.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { query["skills"] = trimmed }
        attempt($error, busy: $busy) {
            let response: MatchResponse = try await API.shared.get("/api/search/people", query: query)
            results = response.results
            searched = true
        }
    }
}
