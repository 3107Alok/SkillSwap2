import SwiftUI

/// The AI project plan with a human in the loop:
/// generate -> the leader reviews -> asks for changes (max 3) or edits tasks directly -> confirm.
struct PlanView: View {
    let project: ProjectDetail
    let onConfirmed: (ProjectDetail) -> Void

    struct MilestoneEdit {
        var title: String
        var assigneeUid: String
        var due: Date
    }

    @Environment(\.dismiss) private var dismiss
    @State private var hours = "72"
    @State private var fixedEnd = false
    @State private var extra = ""
    @State private var draft: PlanDraft?
    @State private var feedback = ""
    @State private var edits: [String: MilestoneEdit] = [:]
    @State private var editing: DraftMilestone?
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        Form {
            if let draft = draft {
                draftSections(draft)
            } else {
                setupSections
            }
            if error != nil { Section { ErrorBanner(message: error) } }
            if busy {
                Section {
                    HStack {
                        ProgressView()
                        Text("The AI is working... this can take up to a minute.").font(.footnote)
                    }
                }
            }
        }
        .navigationTitle("AI plan")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { item in
            EditMilestoneSheet(item: item, members: project.members, current: current(item)) { edit in
                edits[item.id] = edit
            }
        }
    }

    // MARK: step 1, set up

    private var setupSections: some View {
        Group {
            Section(header: Text("Time available"),
                    footer: Text("Fixed end = the plan must finish by then (like the hackathon end). Otherwise you can ask for a later deadline in review and the project end moves.")) {
                HStack {
                    Text("Hours")
                    TextField("72", text: $hours).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                }
                Toggle("Fixed end", isOn: $fixedEnd)
            }
            Section(header: Text("Anything specific? (optional)")) {
                TextField("e.g. include a demo video and a testing task", text: $extra, axis: .vertical)
                    .lineLimit(2...5)
            }
            Section {
                Button("Generate plan") { start() }
                    .disabled(busy || project.members.isEmpty)
            }
        }
    }

    // MARK: step 2, review

    @ViewBuilder
    private func draftSections(_ d: PlanDraft) -> some View {
        Section(header: Text("Draft (changes left: \(d.revisionsLeft))")) {
            if !d.notes.isEmpty { Text("AI: \(d.notes)").font(.footnote) }
            if d.extended, let end = d.end {
                Text("Project end moved to \(Fmt.when(end)).").font(.footnote).foregroundColor(.blue)
            } else if let end = d.end {
                Text("Project ends \(Fmt.when(end)).").font(.footnote).foregroundColor(.secondary)
            }
            if d.changed == false {
                Text("The AI could not change anything for that request.").font(.footnote).foregroundColor(.orange)
            }
            ForEach(d.milestones) { m in
                Button { editing = m } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(shownTitle(m)).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                        Text("\(shownOwner(m)) · \(m.domain) · size \(m.weight)").font(.caption).foregroundColor(.secondary)
                        Text("Due \(shownDue(m))").font(.caption).foregroundColor(.blue)
                        if edits[m.id] != nil { Text("edited by you").font(.caption2).foregroundColor(.orange) }
                    }
                }
            }
        }

        if !d.gaps.isEmpty {
            Section(header: Text("Roles nobody on the team covers")) {
                ForEach(d.gaps) { gap in Text(gap.role + (gap.domain.map { " (\($0))" } ?? "")) }
            }
        }
        if !d.warnings.isEmpty {
            Section(header: Text("Notes")) {
                ForEach(d.warnings, id: \.self) { Text($0).font(.footnote).foregroundColor(.orange) }
            }
        }
        if !d.errors.isEmpty {
            Section(header: Text("Problems")) {
                ForEach(d.errors, id: \.self) { Text($0).font(.footnote).foregroundColor(.red) }
            }
        }

        if d.status == "failed" {
            Section {
                Button("Start over") { draft = nil; edits = [:]; error = nil }
            }
        } else {
            Section(header: Text("Not right yet? Tell the AI what to change"),
                    footer: Text("Tap a task above to change its owner, deadline or title yourself.")) {
                TextField("e.g. give the backend task more time", text: $feedback, axis: .vertical)
                    .lineLimit(2...4)
                Button("Ask AI to change it") { revise() }
                    .disabled(busy || feedback.trimmingCharacters(in: .whitespaces).isEmpty || d.revisionsLeft == 0)
            }
            Section {
                Button("Confirm this plan") { confirm(d) }
                    .buttonStyle(.borderedProminent)
                    .disabled(busy || d.milestones.isEmpty)
            }
        }
    }

    // MARK: showing edits on top of the draft

    private func current(_ m: DraftMilestone) -> MilestoneEdit {
        edits[m.id] ?? MilestoneEdit(title: m.title, assigneeUid: m.assigneeUid, due: Fmt.parse(m.due) ?? Date())
    }

    private func shownTitle(_ m: DraftMilestone) -> String { edits[m.id]?.title ?? m.title }

    private func shownOwner(_ m: DraftMilestone) -> String {
        guard let uid = edits[m.id]?.assigneeUid else { return m.assigneeName }
        return project.members.first(where: { $0.uid == uid })?.name ?? m.assigneeName
    }

    private func shownDue(_ m: DraftMilestone) -> String {
        if let date = edits[m.id]?.due { return Fmt.when(Fmt.iso(date)) }
        return Fmt.when(m.due)
    }

    // MARK: calls

    private func start() {
        let value = Double(hours) ?? 72
        attempt($error, busy: $busy) {
            let fresh: PlanDraft = try await API.shared.post(
                "/api/projects/\(project.id)/plan/start",
                body: ["hours": value, "fixed_end": fixedEnd, "extra": extra], timeout: 150)
            draft = fresh
            edits = [:]
        }
    }

    private func revise() {
        guard let id = draft?.sessionId else { return }
        let text = feedback
        attempt($error, busy: $busy) {
            let fresh: PlanDraft = try await API.shared.post(
                "/api/projects/\(project.id)/plan/revise",
                body: ["session_id": id, "feedback": text], timeout: 150)
            draft = fresh
            edits = [:]          // the AI rebuilt the draft, so your earlier manual edits are gone
            feedback = ""
        }
    }

    private func confirm(_ d: PlanDraft) {
        var list: [[String: Any]] = []
        for (key, value) in edits {
            list.append(["id": key, "title": value.title, "assignee_uid": value.assigneeUid, "due": Fmt.iso(value.due)])
        }
        attempt($error, busy: $busy) {
            let updated: ProjectDetail = try await API.shared.post(
                "/api/projects/\(project.id)/plan/confirm",
                body: ["session_id": d.sessionId, "edits": list])
            onConfirmed(updated)
            dismiss()
        }
    }
}

/// Change one task's title, owner or deadline by hand.
struct EditMilestoneSheet: View {
    let item: DraftMilestone
    let members: [MemberItem]
    let onSave: (PlanView.MilestoneEdit) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var assigneeUid: String
    @State private var due: Date

    init(item: DraftMilestone, members: [MemberItem], current: PlanView.MilestoneEdit,
         onSave: @escaping (PlanView.MilestoneEdit) -> Void) {
        self.item = item
        self.members = members
        self.onSave = onSave
        _title = State(initialValue: current.title)
        _assigneeUid = State(initialValue: current.assigneeUid)
        _due = State(initialValue: current.due)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Task")) {
                    TextField("Title", text: $title)
                }
                Section(header: Text("Owner")) {
                    Picker("Owner", selection: $assigneeUid) {
                        ForEach(members) { member in Text(member.name).tag(member.uid) }
                    }
                }
                Section(header: Text("Deadline"), footer: Text("Must be before the project end.")) {
                    DatePicker("Due", selection: $due, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("Edit task")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(PlanView.MilestoneEdit(title: title, assigneeUid: assigneeUid, due: due))
                        dismiss()
                    }
                }
            }
        }
    }
}
