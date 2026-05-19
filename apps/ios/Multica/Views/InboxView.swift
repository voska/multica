import SwiftUI

enum InboxFilter: String, CaseIterable, Identifiable {
    case all, unread, agents
    var id: String { rawValue }
    var title: LocalizedStringResource {
        switch self {
        case .all: "All"
        case .unread: "Unread"
        case .agents: "Agents"
        }
    }
}

struct InboxView: View {
    @Environment(AppState.self) private var app
    @State private var filter: InboxFilter = .all
    @State private var search = ""
    @State private var showingWorkspaceSwitcher = false
    @State private var showingCreateIssue = false

    private var filtered: [InboxItem] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return app.inbox.filter { item in
            let filterMatches: Bool = {
                switch filter {
                case .all: return true
                case .unread: return !item.read
                case .agents:
                    let isAgentType = item.type.localizedCaseInsensitiveContains("agent")
                    return isAgentType
                }
            }()
            let searchMatches = q.isEmpty
                || item.title.lowercased().contains(q)
                || (item.body?.lowercased().contains(q) ?? false)
            return filterMatches && searchMatches
        }
    }

    private var bucketed: [(MulticaTime.Bucket, [InboxItem])] {
        let groups = Dictionary(grouping: filtered) { MulticaTime.bucket($0.createdAt) }
        return MulticaTime.Bucket.allCases.compactMap { bucket in
            guard let items = groups[bucket], !items.isEmpty else { return nil }
            return (bucket, items.sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") })
        }
    }

    private var liveAgents: [Agent] {
        app.agents.filter(\.statusEnum.isLive)
    }

    var body: some View {
        List {
            Section {
                Picker("Filter", selection: $filter) {
                    ForEach(InboxFilter.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if !liveAgents.isEmpty {
                Section {
                    LiveAgentsStrip(agents: liveAgents)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }

            if filtered.isEmpty {
                Section {
                    EmptyState(
                        title: app.inbox.isEmpty ? "Inbox zero" : "Nothing here",
                        message: app.inbox.isEmpty
                            ? "When agents act or your work changes, it shows up here."
                            : "Nothing matches this filter.",
                        systemImage: "tray"
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } else {
                ForEach(bucketed, id: \.0) { bucket in
                    Section {
                        ForEach(bucket.1) { item in
                            NavigationLink(value: InboxDestination.event(item)) {
                                InboxRow(item: item)
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .leading) {
                                if !item.read {
                                    Button {
                                        Task { await app.markInboxRead(item) }
                                    } label: { Label("Read", systemImage: "envelope.open") }
                                    .tint(MulticaTheme.brand)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await app.archiveInbox(item) }
                                } label: { Label("Archive", systemImage: "archivebox") }
                            }
                        }
                    } header: {
                        Text(bucket.0.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                workspaceTitleMenu
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreateIssue = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("New issue")
            }
        }
        .searchable(text: $search, prompt: "Search inbox")
        .refreshable { await app.refreshAll() }
        .sheet(isPresented: $showingWorkspaceSwitcher) { WorkspaceSwitcherSheet() }
        .sheet(isPresented: $showingCreateIssue) { CreateIssueSheet() }
        .sensoryFeedback(.selection, trigger: filter)
    }

    private var workspaceTitleMenu: some View {
        Menu {
            ForEach(app.workspaces.prefix(8)) { workspace in
                Button {
                    Task { await app.selectWorkspace(workspace) }
                } label: {
                    if workspace.id == app.selectedWorkspace?.id {
                        Label(workspace.name, systemImage: "checkmark")
                    } else {
                        Text(workspace.name)
                    }
                }
            }
            if app.workspaces.count > 8 {
                Divider()
                Button { showingWorkspaceSwitcher = true } label: {
                    Label("All workspaces…", systemImage: "ellipsis")
                }
            }
            Divider()
            Button {
                showingWorkspaceSwitcher = true
            } label: { Label("Manage…", systemImage: "gearshape") }
        } label: {
            HStack(spacing: 5) {
                WorkspaceAvatar(
                    name: app.selectedWorkspace?.name ?? "Multica",
                    url: URL(string: app.selectedWorkspace?.avatarUrl ?? ""),
                    size: 22
                )
                Text(app.selectedWorkspace?.name ?? "Multica")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("Switch workspace")
    }
}

struct InboxRow: View {
    @Environment(AppState.self) private var app
    let item: InboxItem

    private var relatedIssue: Issue? {
        guard let id = item.issueId else { return nil }
        return app.issues.first { $0.id == id }
    }

    private var actorName: String {
        if item.type.localizedCaseInsensitiveContains("agent") {
            let agent = app.agents.first { item.body?.contains($0.name) ?? false }
            return agent?.name ?? "Agent"
        }
        return "Multica"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ActorAvatar(
                name: actorName,
                url: nil,
                size: 32,
                isAgent: item.type.localizedCaseInsensitiveContains("agent")
            )
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if !item.read {
                        Circle()
                            .fill(MulticaTheme.brand)
                            .frame(width: 6, height: 6)
                    }
                    Text(item.title)
                        .font(.subheadline.weight(item.read ? .regular : .semibold))
                        .foregroundStyle(item.read ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if let relative = MulticaTime.relativeShort(from: item.createdAt) {
                        Text(relative)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    if let status = relatedIssue?.statusEnum {
                        IssueStatusIcon(status: status, size: 12)
                    }
                }
                if let body = item.body, !body.isEmpty {
                    Text(body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let issue = relatedIssue, let identifier = issue.identifier {
                    Text(identifier)
                        .font(.caption2.monospaced().weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(item.read ? "" : "Unread. ")\(item.title)"))
    }
}

private struct LiveAgentsStrip: View {
    let agents: [Agent]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                AgentLiveDot(isLive: true)
                Text("Live now")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(agents.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(agents.prefix(10)) { agent in
                        NavigationLink(value: InboxDestination.event(InboxItem(id: agent.id, workspaceId: agent.workspaceId, type: "agent", severity: nil, issueId: nil, title: agent.name, body: agent.description, issueStatus: nil, read: true, archived: false, createdAt: agent.updatedAt))) {
                            LiveAgentCard(agent: agent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct LiveAgentCard: View {
    let agent: Agent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ActorAvatar(name: agent.name, url: URL(string: agent.avatarUrl ?? ""), size: 26, isAgent: true)
                Spacer(minLength: 0)
                AgentLiveDot(isLive: agent.statusEnum.isLive)
            }
            Text(agent.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text(agent.model ?? agent.statusEnum.title.localized)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 140, alignment: .leading)
        .cardSurface(padding: 10)
    }
}

private extension LocalizedStringResource {
    var localized: String { String(localized: self) }
}

struct InboxEventDetailView: View {
    let item: InboxItem
    @Environment(AppState.self) private var app

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(item.type.displayLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let relative = MulticaTime.relativeShort(from: item.createdAt) {
                            Text(relative)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Text(item.title)
                        .font(.title3.weight(.semibold))
                    if let body = item.body, !body.isEmpty {
                        Text(body)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                if let id = item.issueId, let issue = app.issues.first(where: { $0.id == id }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Related issue")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        NavigationLink(value: InboxDestination.issue(issue)) {
                            IssueRow(issue: issue)
                        }
                        .buttonStyle(.plain)
                    }
                    .cardSurface()
                }

                HStack(spacing: 10) {
                    if !item.read {
                        Button {
                            Task { await app.markInboxRead(item) }
                        } label: { Label("Mark read", systemImage: "envelope.open") }
                        .buttonStyle(GhostButtonStyle())
                    }
                    Button(role: .destructive) {
                        Task { await app.archiveInbox(item) }
                    } label: { Label("Archive", systemImage: "archivebox") }
                    .buttonStyle(GhostButtonStyle())
                }
            }
            .padding(16)
        }
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension String {
    var displayLabel: String {
        split(separator: "_").map { part in
            part.prefix(1).uppercased() + part.dropFirst()
        }.joined(separator: " ")
    }
}
