import SwiftUI

struct ProjectDetailView: View {
    let projectId: String

    @State private var project: ProjectDetail?
    @State private var error: String?
    @State private var notice: String?
    @State private var busy = false
    @State private var confirmComplete = false
    @State private var applyTarget: ApplyTarget?
    @State private var applyMessage = ""

    /// What the student is applying for (a specific role, or just to join).
    struct ApplyTarget: Identifiable {
        let needIndex: Int?
        let title: String
        var id: String { String(needIndex ?? -1) }
    }

    var body: some View {
        List {
            if error != nil { Section { ErrorBanner(message: error) } }
            if let notice = notice {
                Section { Text(notice).font(.footnote).foregroundColor(.green) }
            }
            if let p = project {
                content(p)
            } else if error == nil {
                ProgressView()
            }
        }
        .navigationTitle(project?.title ?? "Project")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .confirmationDialog("Mark this project as completed?", isPresented: $confirmComplete, titleVisibility: .visible) {
            Button("Complete project") { complete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your leader tag is removed, but 'Led: this project' stays on your profile for good.")
        }
        .sheet(item: $applyTarget) { target in applySheet(target) }
    }

    // MARK: sections

    @ViewBuilder
    private func content(_ p: ProjectDetail) -> some View {
        Section {
            if !p.description.isEmpty { Text(p.description) }
            HStack {
                Pill(text: p.status == "active" ? "Active" : "Completed", color: p.status == "active" ? .blue : .green)
                Pill(text: "Leader: \(p.leaderName)", color: .purple)
            }
            if let deadline = p.deadline {
                Label("Ends \(Fmt.when(deadline))", systemImage: "calendar").font(.footnote)
            }
        }

        Section(header: Text("Team")) {
            ForEach(p.members) { member in
                NavigationLink(destination: UserDetailView(uid: member.uid)) {
                    HStack(spacing: 10) {
                        AvatarView(path: member.avatarUrl, size: 36)
                        VStack(alignment: .leading) {
                            Text(member.name)
                            if !member.role.isEmpty { Text(member.role).font(.caption).foregroundColor(.secondary) }
                        }
                        Spacer()
                        if member.isLeader { Pill(text: "Leader", color: .purple) }
                    }
                }
            }
            if p.viewer.isLeader && p.status == "active" {
                NavigationLink(destination: RequestsView(projectId: p.id, onChanged: { Task { await load() } })) {
                    Label("Join requests", systemImage: "tray")
                }
            }
        }

        if !p.needs.isEmpty {
            Section(header: Text("Roles")) {
                ForEach(p.needs) { need in needRow(p, need) }
            }
        }
        if !p.viewer.isMember && p.status == "active" {
            Section {
                if p.viewer.hasApplied {
                    Text("You have applied. The leader will answer soon.").font(.footnote).foregroundColor(.secondary)
                }
                Button("Apply to join") { applyTarget = ApplyTarget(needIndex: nil, title: p.title) }
            }
        }

        if p.viewer.isLeader && p.status == "active" {
            Section(header: Text("Plan"), footer: Text("The AI drafts milestones and owners from your project description. You review, ask for changes (up to 3 times), then confirm.")) {
                NavigationLink(destination: PlanView(project: p, onConfirmed: { updated in
                    project = updated
                    notice = "Plan confirmed."
                })) {
                    Label(p.milestones.isEmpty ? "Plan this project with AI" : "Re-plan with AI", systemImage: "wand.and.stars")
                }
            }
        }

        if !p.milestones.isEmpty {
            Section(header: Text("Milestones")) {
                ForEach(p.milestones) { m in milestoneRow(p, m) }
            }
        }

        if p.viewer.isLeader && p.status == "active" {
            Section(header: Text("Leader tools")) {
                Menu {
                    ForEach(p.members.filter { $0.uid != p.leaderUid }) { member in
                        Button(member.name) { transfer(to: member.uid) }
                    }
                } label: {
                    Label("Hand over leadership", systemImage: "arrow.left.arrow.right")
                }
                Button(role: .destructive) { confirmComplete = true } label: {
                    Label("Complete project", systemImage: "checkmark.seal")
                }
            }
        }
    }

    @ViewBuilder
    private func needRow(_ p: ProjectDetail, _ need: NeedItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(need.role).font(.headline)
                Spacer()
                if let name = need.filledByName {
                    Pill(text: name, color: .green)
                } else {
                    Pill(text: "Open", color: .orange)
                }
            }
            if let domain = need.domain { Text(domain).font(.caption).foregroundColor(.secondary) }
            if !need.skills.isEmpty { Text(need.skills.joined(separator: " · ")).font(.caption) }
            if need.filledBy == nil && p.status == "active" {
                if p.viewer.isLeader {
                    NavigationLink(destination: CandidatesView(projectId: p.id, need: need, onAdded: { Task { await load() } })) {
                        Text("Find best-fit people").font(.subheadline).foregroundColor(.blue)
                    }
                } else if !p.viewer.isMember {
                    Button("Apply for this role") { applyTarget = ApplyTarget(needIndex: need.index, title: need.role) }
                        .font(.subheadline)
                        .buttonStyle(.borderless)
                }
            }
        }
    }

    @ViewBuilder
    private func milestoneRow(_ p: ProjectDetail, _ m: MilestoneItem) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(m.title).font(.subheadline.weight(.semibold))
                Text("\(m.assigneeName) · \(m.domain)").font(.caption).foregroundColor(.secondary)
                HStack {
                    Text("Due \(Fmt.when(m.due))").font(.caption)
                    Pill(text: m.status == "pending" && m.overdue ? "overdue" : m.status,
                         color: m.status == "pending" && m.overdue ? .red : statusColor(m.status))
                }
                if m.reportsNeeded > 0 && m.status == "pending" && m.overdue {
                    Text("Teammates who reported this: \(m.reports)/\(m.reportsNeeded)").font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            if m.canMark || m.canReport || m.canHandOver {
                Menu {
                    if m.canMark {
                        Button("Mark done") { mark(m, "done") }
                        if m.canMarkMissed { Button("Mark missed", role: .destructive) { mark(m, "missed") } }
                        Button("Mark abandoned", role: .destructive) { mark(m, "abandoned") }
                        Button("Excuse (no penalty)") { mark(m, "excused") }
                    }
                    if m.canReport {
                        Button("Report: leader missed this") { report(m) }
                    }
                    if m.canHandOver {
                        Menu("Hand over to...") {
                            ForEach(p.members.filter { $0.uid != m.assigneeUid }) { member in
                                Button(member.name) { handOver(m, to: member.uid) }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.title3)
                }
            }
        }
    }

    private func applySheet(_ target: ApplyTarget) -> some View {
        NavigationStack {
            Form {
                Section(header: Text("Applying for: \(target.title)")) {
                    TextField("Tell the leader why you fit (optional)", text: $applyMessage, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Apply")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { applyTarget = nil } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") { sendApplication(target) }
                }
            }
        }
    }

    // MARK: actions

    private func load() async {
        do {
            let fresh: ProjectDetail = try await API.shared.get("/api/projects/\(projectId)")
            project = fresh
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func sendApplication(_ target: ApplyTarget) {
        var body: [String: Any] = ["message": applyMessage]
        if let index = target.needIndex { body["need_index"] = index }
        applyTarget = nil
        attempt($error, busy: $busy) {
            let _: OkResponse = try await API.shared.post("/api/projects/\(projectId)/apply", body: body)
            applyMessage = ""
            notice = "Application sent."
            await load()
        }
    }

    private func mark(_ m: MilestoneItem, _ outcome: String) {
        attempt($error, busy: $busy) {
            let updated: ProjectDetail = try await API.shared.post("/api/projects/\(projectId)/milestones/\(m.id)/mark", body: ["outcome": outcome])
            project = updated
            notice = "Marked \(outcome)."
        }
    }

    private func handOver(_ m: MilestoneItem, to uid: String) {
        attempt($error, busy: $busy) {
            let updated: ProjectDetail = try await API.shared.post("/api/projects/\(projectId)/milestones/\(m.id)/handover", body: ["to_uid": uid])
            project = updated
            notice = "Task handed over. No penalty for a proper handover."
        }
    }

    private func report(_ m: MilestoneItem) {
        attempt($error, busy: $busy) {
            let updated: ProjectDetail = try await API.shared.post("/api/projects/\(projectId)/milestones/\(m.id)/report")
            project = updated
            if let r = updated.reportResult {
                notice = r.applied ? "All teammates reported it, so the task is marked missed."
                                   : "Report recorded (\(r.reports) of \(r.needed) teammates). It counts only when all report."
            }
        }
    }

    private func transfer(to uid: String) {
        attempt($error, busy: $busy) {
            let updated: ProjectDetail = try await API.shared.post("/api/projects/\(projectId)/leader", body: ["uid": uid])
            project = updated
            notice = "Leadership handed over."
        }
    }

    private func complete() {
        attempt($error, busy: $busy) {
            let updated: ProjectDetail = try await API.shared.post("/api/projects/\(projectId)/complete")
            project = updated
            notice = "Project completed."
        }
    }
}
