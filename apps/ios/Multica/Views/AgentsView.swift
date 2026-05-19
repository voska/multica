import SwiftUI

enum AgentsSection: String, CaseIterable, Identifiable {
    case agents, squads
    var id: String { rawValue }
    var title: LocalizedStringResource {
        switch self {
        case .agents: "Agents"
        case .squads: "Squads"
        }
    }
}

struct AgentsView: View {
    @Environment(AppState.self) private var app
    @State private var section: AgentsSection = .agents
    @State private var search = ""
    @State private var showArchived = false

    var body: some View {
        Group {
            switch section {
            case .agents: agentsContent
            case .squads: squadsContent
            }
        }
        .navigationTitle(section == .agents ? "Agents" : "Squads")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("Show archived", isOn: $showArchived)
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .searchable(text: $search, prompt: section == .agents ? "Search agents" : "Search squads")
        .refreshable { await app.refreshAll() }
        .sensoryFeedback(.selection, trigger: section)
    }

    // MARK: - Agents

    private var filteredAgents: [Agent] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return app.agents.filter { agent in
            let archivedMatches = showArchived || !agent.isArchived
            let searchMatches = q.isEmpty
                || agent.name.lowercased().contains(q)
                || (agent.description ?? "").lowercased().contains(q)
                || (agent.model ?? "").lowercased().contains(q)
            return archivedMatches && searchMatches
        }
    }

    private var liveAgents: [Agent] {
        filteredAgents.filter(\.statusEnum.isLive)
    }

    private var groupedAgents: [(AgentRuntimeStatus, [Agent])] {
        let groups = Dictionary(grouping: filteredAgents.filter { !$0.statusEnum.isLive }, by: \.statusEnum)
        let order: [AgentRuntimeStatus] = [.online, .idle, .error, .offline, .unknown]
        return order.compactMap { status in
            guard let items = groups[status], !items.isEmpty else { return nil }
            return (status, items.sorted { $0.name < $1.name })
        }
    }

    @ViewBuilder private var agentsContent: some View {
        List {
            Section {
                Picker("Section", selection: $section) {
                    ForEach(AgentsSection.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            if filteredAgents.isEmpty {
                Section {
                    EmptyState(
                        title: app.agents.isEmpty ? "No agents" : "No matches",
                        message: app.agents.isEmpty
                            ? "Add agents on the web to start automating work."
                            : "Try a different filter or search.",
                        systemImage: "bolt.slash"
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            } else {
                if !liveAgents.isEmpty {
                    Section {
                        ForEach(liveAgents) { agent in
                            NavigationLink(value: AgentsDestination.agent(agent)) {
                                AgentRow(agent: agent, live: true)
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                    } header: {
                        HStack(spacing: 6) {
                            AgentLiveDot(isLive: true)
                            Text("Live")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(liveAgents.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                                .contentTransition(.numericText())
                        }
                        .textCase(nil)
                    }
                }
                ForEach(groupedAgents, id: \.0) { group in
                    Section {
                        ForEach(group.1) { agent in
                            NavigationLink(value: AgentsDestination.agent(agent)) {
                                AgentRow(agent: agent, live: false)
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                    } header: {
                        HStack {
                            Text(group.0.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(group.0.tint)
                            Spacer()
                            Text("\(group.1.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                        .textCase(nil)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Squads

    private var filteredSquads: [Squad] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return app.squads.filter { squad in
            let archivedMatches = showArchived || !squad.isArchived
            let searchMatches = q.isEmpty
                || squad.name.lowercased().contains(q)
                || (squad.description ?? "").lowercased().contains(q)
            return archivedMatches && searchMatches
        }
    }

    @ViewBuilder private var squadsContent: some View {
        List {
            Section {
                Picker("Section", selection: $section) {
                    ForEach(AgentsSection.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            if filteredSquads.isEmpty {
                Section {
                    EmptyState(
                        title: app.squads.isEmpty ? "No squads" : "No matches",
                        message: app.squads.isEmpty
                            ? "Squads route work through a leader agent."
                            : "Try a different filter or search.",
                        systemImage: "person.2.slash"
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(filteredSquads) { squad in
                        NavigationLink(value: AgentsDestination.squad(squad)) {
                            SquadRow(squad: squad)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

struct AgentRow: View {
    let agent: Agent
    let live: Bool

    var body: some View {
        HStack(spacing: 12) {
            ActorAvatar(name: agent.name, url: URL(string: agent.avatarUrl ?? ""), size: 36, isAgent: true)
                .overlay(alignment: .bottomTrailing) {
                    if live {
                        AgentLiveDot(isLive: true)
                            .padding(2)
                            .background(Circle().fill(Color(.systemBackground)))
                    }
                }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(agent.name)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if let updated = MulticaTime.relativeShort(from: agent.updatedAt) {
                        Text(updated)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
                if let description = agent.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    Label(agent.statusEnum.title, systemImage: "circle.fill")
                        .labelStyle(.titleOnly)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(agent.statusEnum.tint)
                    if let model = agent.model {
                        HStack(spacing: 3) {
                            Image(systemName: "cpu")
                                .imageScale(.small)
                            Text(model)
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct SquadRow: View {
    @Environment(AppState.self) private var app
    let squad: Squad

    private var leaderAgent: Agent? {
        guard let id = squad.leaderId else { return nil }
        return app.agents.first { $0.id == id }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(MulticaTheme.brand.opacity(0.15))
                Image(systemName: "person.3.fill")
                    .foregroundStyle(MulticaTheme.brand)
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(squad.name).font(.subheadline.weight(.semibold))
                    if squad.isArchived {
                        Text("Archived")
                            .font(.caption2)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(MulticaTheme.muted, in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
                if let description = squad.description, !description.isEmpty {
                    Text(description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                if let leader = leaderAgent {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .imageScale(.small)
                            .foregroundStyle(MulticaTheme.warning)
                        Text(leader.name).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Agent detail

struct AgentDetailView: View {
    let agent: Agent
    @Environment(AppState.self) private var app

    private var assignedIssues: [Issue] {
        app.issues
            .filter { $0.assigneeType == "agent" && $0.assigneeId == agent.id }
            .sorted { $0.priorityEnum.rank < $1.priorityEnum.rank }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroCard
                if let description = agent.description?.trimmedOrNil {
                    Text(description).font(.body).foregroundStyle(.secondary).textSelection(.enabled)
                }
                metadataCard
                if !assignedIssues.isEmpty {
                    issuesSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle(agent.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await app.refreshAll() }
    }

    private var heroCard: some View {
        HStack(spacing: 14) {
            ActorAvatar(name: agent.name, url: URL(string: agent.avatarUrl ?? ""), size: 52, isAgent: true)
            VStack(alignment: .leading, spacing: 4) {
                Text(agent.name).font(.title3.weight(.bold))
                HStack(spacing: 6) {
                    AgentLiveDot(isLive: agent.statusEnum.isLive)
                    Text(agent.statusEnum.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(agent.statusEnum.tint)
                }
                if let model = agent.model {
                    HStack(spacing: 3) {
                        Image(systemName: "cpu").imageScale(.small)
                        Text(model)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private var metadataCard: some View {
        VStack(spacing: 0) {
            row(icon: "circle.fill", title: "Status", value: AnyView(Text(agent.statusEnum.title).foregroundStyle(agent.statusEnum.tint)))
            Divider().padding(.leading, 14)
            row(icon: "gearshape", title: "Runtime", value: AnyView(Text(agent.runtimeMode?.displayLabel ?? "—").foregroundStyle(.secondary)))
            Divider().padding(.leading, 14)
            row(icon: agent.visibility == "private" ? "lock.fill" : "globe", title: "Visibility", value: AnyView(Text(agent.visibility?.displayLabel ?? "Workspace").foregroundStyle(.secondary)))
            if let created = MulticaDate.mediumDate(agent.createdAt) {
                Divider().padding(.leading, 14)
                row(icon: "calendar", title: "Created", value: AnyView(Text(created).foregroundStyle(.secondary)))
            }
        }
        .cardSurface(padding: 0)
    }

    private func row(icon: String, title: LocalizedStringResource, value: AnyView) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(title).font(.subheadline)
            Spacer()
            value.font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Assigned issues").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(assignedIssues.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            VStack(spacing: 0) {
                ForEach(Array(assignedIssues.prefix(10).enumerated()), id: \.element.id) { index, issue in
                    NavigationLink(value: IssueDestination.issue(issue)) {
                        IssueRow(issue: issue).padding(.horizontal, 14).padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    if index < min(9, assignedIssues.count - 1) {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .cardSurface(padding: 0)
        }
    }
}

// MARK: - Squad detail

struct SquadDetailView: View {
    let squad: Squad
    @Environment(AppState.self) private var app
    @State private var current: Squad
    @State private var members: [SquadMember] = []

    init(squad: Squad) {
        self.squad = squad
        _current = State(initialValue: squad)
    }

    private var leader: Agent? {
        guard let id = current.leaderId else { return nil }
        return app.agents.first { $0.id == id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                if let description = current.description?.trimmedOrNil {
                    Text(description).font(.body).foregroundStyle(.secondary).textSelection(.enabled)
                }
                membersCard
                if let instructions = current.instructions?.trimmedOrNil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instructions").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(instructions).font(.body).textSelection(.enabled).cardSurface()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle(current.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private var hero: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(MulticaTheme.brand.opacity(0.18))
                Image(systemName: "person.3.fill")
                    .foregroundStyle(MulticaTheme.brand)
                    .font(.title3)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(current.name).font(.title3.weight(.bold))
                if let leader {
                    HStack(spacing: 5) {
                        Image(systemName: "crown.fill").foregroundStyle(MulticaTheme.warning).imageScale(.small)
                        Text(leader.name).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
    }

    private var membersCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Members").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if members.isEmpty {
                Text("No members loaded.").font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                        memberRow(member)
                        if index < members.count - 1 { Divider().padding(.leading, 14) }
                    }
                }
                .cardSurface(padding: 0)
            }
        }
    }

    private func memberRow(_ member: SquadMember) -> some View {
        let name: String = {
            if member.memberType == "agent" {
                return app.agents.first { $0.id == member.memberId }?.name ?? member.memberId
            }
            return member.memberId
        }()
        let isLeader = member.memberId == current.leaderId
        return HStack(spacing: 12) {
            ActorAvatar(name: name, url: nil, size: 28, isAgent: member.memberType == "agent")
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline.weight(.medium))
                Text(member.memberType.displayLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isLeader {
                Label("Leader", systemImage: "crown.fill")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .foregroundStyle(MulticaTheme.warning)
                    .background(MulticaTheme.warning.opacity(0.14), in: Capsule())
            } else if let role = member.role, !role.isEmpty {
                Text(role).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func load() async {
        if let loaded = await app.loadSquadDetail(squadID: squad.id) {
            current = loaded
        }
        members = app.squadMembers(for: squad.id)
    }
}
