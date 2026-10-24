import SwiftUI

struct RoleDraft: Identifiable {
    let id = UUID()
    var role = ""
    var domain = ""
    var skills = ""
}

struct CreateProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var details = ""
    @State private var roles: [RoleDraft] = [RoleDraft()]
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Project")) {
                    TextField("Title", text: $title)
                    TextField("What are you building? (the AI plans from this)", text: $details, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section(header: Text("Roles you still need"),
                        footer: Text("Pick the domain and list skills, comma separated. We suggest the best-fitting students for each role.")) {
                    ForEach($roles) { $role in
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Role, e.g. iOS developer", text: $role.role)
                            Picker("Domain", selection: $role.domain) {
                                Text("Any").tag("")
                                ForEach(Domains.all, id: \.self) { Text($0).tag($0) }
                            }
                            TextField("Skills, e.g. Swift, SwiftUI", text: $role.skills)
                                .textInputAutocapitalization(.never)
                        }
                    }
                    .onDelete { roles.remove(atOffsets: $0) }
                    Button("Add another role") { roles.append(RoleDraft()) }
                }
                if error != nil {
                    Section { ErrorBanner(message: error) }
                }
            }
            .navigationTitle("New project")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(busy ? "Saving..." : "Create") { create() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).count < 3 || busy)
                }
            }
        }
    }

    private func create() {
        attempt($error, busy: $busy) {
            let needs: [[String: Any]] = roles
                .filter { !$0.role.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { (draft: RoleDraft) -> [String: Any] in
                    let skills = draft.skills.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    return ["role": draft.role, "domain": draft.domain, "skills": skills]
                }
            let _: ProjectDetail = try await API.shared.post(
                "/api/projects", body: ["title": title, "description": details, "needs": needs])
            dismiss()
        }
    }
}
