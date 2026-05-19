import SwiftUI

struct IssueDetailView: View {
    @Environment(AppState.self) private var app
    @State var issue: Issue
    @State private var comments: [Comment] = []
    @State private var commentDraft = ""
    @State private var loadingComments = false
    @State private var postingComment = false
    @FocusState private var commentFocused: Bool

    private var assignedAgent: Agent? {
        guard issue.assigneeType == "agent", let id = issue.assigneeId else { return nil }
        return app.agents.first { $0.id == id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let description = issue.description?.trimmedOrNil {
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                workflowCard
                if !comments.isEmpty || loadingComments {
                    commentsSection
                }
                composer
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(issue.identifier ?? "Issue")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section("Status") {
                        ForEach(IssueStatus.workflowOrder) { status in
                            Button {
                                Task { await change(status: status) }
                            } label: { Label(status.title, systemImage: "circle") }
                        }
                    }
                    Section("Priority") {
                        ForEach(IssuePriority.allCases) { priority in
                            Button {
                                Task { await change(priority: priority) }
                            } label: { Label(priority.title, systemImage: priority.systemImage) }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task { await loadDetail() }
        .refreshable { await loadDetail() }
        .sensoryFeedback(.success, trigger: issue.statusEnum) { old, new in
            old != new && new == .done
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let identifier = issue.identifier {
                    Text(identifier)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let updated = MulticaTime.relativeShort(from: issue.updatedAt ?? issue.createdAt) {
                    Text("Updated \(updated)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
            Text(issue.title)
                .font(.title2.weight(.bold))
                .textSelection(.enabled)
            HStack(spacing: 8) {
                StatusChip(status: issue.statusEnum)
                PriorityChip(priority: issue.priorityEnum)
                if let agent = assignedAgent {
                    HStack(spacing: 5) {
                        ActorAvatar(name: agent.name, url: URL(string: agent.avatarUrl ?? ""), size: 18, isAgent: true)
                        Text(agent.name)
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(MulticaTheme.brand.opacity(0.10), in: Capsule())
                }
            }
        }
    }

    private var workflowCard: some View {
        VStack(spacing: 0) {
            workflowRow(
                title: "Status",
                value: AnyView(StatusChip(status: issue.statusEnum)),
                menu: AnyView(
                    ForEach(IssueStatus.workflowOrder) { status in
                        Button { Task { await change(status: status) } } label: {
                            Label(status.title, systemImage: "circle")
                        }
                    }
                )
            )
            Divider().padding(.leading, 14)
            workflowRow(
                title: "Priority",
                value: AnyView(PriorityChip(priority: issue.priorityEnum)),
                menu: AnyView(
                    ForEach(IssuePriority.allCases) { priority in
                        Button { Task { await change(priority: priority) } } label: {
                            Label(priority.title, systemImage: priority.systemImage)
                        }
                    }
                )
            )
            if let due = MulticaDate.mediumDate(issue.dueDate) {
                Divider().padding(.leading, 14)
                workflowRow(
                    title: "Due",
                    value: AnyView(Text(due).font(.caption.weight(.semibold)).foregroundStyle(.secondary)),
                    menu: AnyView(EmptyView())
                )
            }
        }
        .cardSurface(padding: 0)
    }

    private func workflowRow(title: LocalizedStringResource, value: AnyView, menu: AnyView) -> some View {
        Menu {
            menu
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                value
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Activity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if loadingComments { ProgressView().controlSize(.mini) }
            }
            VStack(spacing: 12) {
                ForEach(comments) { comment in
                    CommentRow(comment: comment)
                }
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Add a comment", text: $commentDraft, axis: .vertical)
                    .lineLimit(1...6)
                    .padding(10)
                    .background(MulticaTheme.muted, in: RoundedRectangle(cornerRadius: MulticaTheme.radius, style: .continuous))
                    .focused($commentFocused)
                Button {
                    Task { await addComment() }
                } label: {
                    if postingComment {
                        ProgressView().controlSize(.small).tint(.white)
                            .padding(10)
                            .background(MulticaTheme.brand, in: Circle())
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(MulticaTheme.brand, in: Circle())
                    }
                }
                .disabled(commentDraft.trimmedOrNil == nil || postingComment)
                .opacity(commentDraft.trimmedOrNil == nil ? 0.4 : 1)
            }
        }
    }

    private func loadDetail() async {
        loadingComments = true
        defer { loadingComments = false }
        if let detail = await app.loadIssueDetail(issueID: issue.id) {
            issue = detail.issue
            comments = detail.comments
        }
    }

    private func change(status: IssueStatus? = nil, priority: IssuePriority? = nil) async {
        if let updated = await app.updateIssue(issue, status: status, priority: priority) {
            issue = updated
        }
    }

    private func addComment() async {
        let body = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        postingComment = true
        defer { postingComment = false }
        if let comment = await app.createComment(issueID: issue.id, content: body) {
            comments.append(comment)
            commentDraft = ""
            commentFocused = false
        }
    }
}

private struct CommentRow: View {
    let comment: Comment
    @Environment(AppState.self) private var app

    private var authorName: String {
        if comment.authorType == "agent", let id = comment.authorId {
            return app.agents.first { $0.id == id }?.name ?? "Agent"
        }
        if comment.authorType == "member", let id = comment.authorId,
           id == app.currentUser?.id {
            return app.currentUser?.name ?? "You"
        }
        return comment.authorType?.capitalized ?? "Member"
    }

    private var isAgent: Bool { comment.authorType == "agent" }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ActorAvatar(name: authorName, url: nil, size: 28, isAgent: isAgent)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(authorName)
                        .font(.caption.weight(.semibold))
                    if let relative = MulticaTime.relativeShort(from: comment.createdAt) {
                        Text("·").foregroundStyle(.tertiary)
                        Text(relative)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                Text(comment.content)
                    .font(.body)
                    .textSelection(.enabled)
            }
        }
    }
}
