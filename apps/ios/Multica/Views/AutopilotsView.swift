import SwiftUI

struct AutopilotsView: View {
    @Environment(AppState.self) private var app
    @State private var statusFilter: AutopilotStatus? = nil
    @State private var search = ""

    private var filtered: [Autopilot] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return app.autopilots.filter { auto in
            let statusMatches = statusFilter.map { auto.statusEnum == $0 } ?? (auto.statusEnum != .archived)
            let searchMatches = q.isEmpty
                || auto.title.lowercased().contains(q)
                || (auto.description ?? "").lowercased().contains(q)
            return statusMatches && searchMatches
        }
    }

    private var grouped: [(AutopilotStatus, [Autopilot])] {
        let groups = Dictionary(grouping: filtered, by: \.statusEnum)
        let order: [AutopilotStatus] = [.active, .paused, .archived]
        return order.compactMap { status in
            guard let items = groups[status], !items.isEmpty else { return nil }
            return (status, items.sorted { ($0.lastRunAt ?? "") > ($1.lastRunAt ?? "") })
        }
    }

    var body: some View {
        List {
            if filtered.isEmpty {
                Section {
                    EmptyState(
                        title: app.autopilots.isEmpty ? "No autopilots" : "No matches",
                        message: app.autopilots.isEmpty
                            ? "Autopilots run scheduled work — set them up on the web."
                            : "Try a different filter.",
                        systemImage: "infinity"
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            } else {
                ForEach(grouped, id: \.0) { group in
                    Section {
                        ForEach(group.1) { auto in
                            NavigationLink(value: AutopilotsDestination.autopilot(auto)) {
                                AutopilotRow(autopilot: auto)
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .swipeActions(edge: .leading) {
                                Button {
                                    Task { _ = await app.triggerAutopilot(auto) }
                                } label: { Label("Run", systemImage: "play.fill") }
                                .tint(MulticaTheme.brand)
                            }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    Task { _ = await app.setAutopilotStatus(auto, status: auto.isActive ? .paused : .active) }
                                } label: {
                                    if auto.isActive {
                                        Label("Pause", systemImage: "pause.fill")
                                    } else {
                                        Label("Activate", systemImage: "bolt.fill")
                                    }
                                }
                                .tint(auto.isActive ? MulticaTheme.warning : MulticaTheme.success)
                            }
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: group.0.systemImage)
                                .foregroundStyle(group.0.tint)
                                .imageScale(.small)
                            Text(group.0.title).font(.caption.weight(.semibold))
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
        .navigationTitle("Autopilots")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Status", selection: $statusFilter) {
                        Text("Active & paused").tag(AutopilotStatus?.none)
                        ForEach(AutopilotStatus.allCases, id: \.self) { status in
                            Text(status.title).tag(Optional(status))
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .searchable(text: $search, prompt: "Search autopilots")
        .refreshable { await app.refreshAll() }
    }
}

struct AutopilotRow: View {
    @Environment(AppState.self) private var app
    let autopilot: Autopilot

    private var assigneeAgent: Agent? {
        app.agents.first { $0.id == autopilot.assigneeId }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(autopilot.statusEnum.tint.opacity(0.16))
                Image(systemName: autopilot.statusEnum.systemImage)
                    .foregroundStyle(autopilot.statusEnum.tint)
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(autopilot.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    Spacer()
                    if let last = MulticaTime.relativeShort(from: autopilot.lastRunAt) {
                        Text(last)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
                if let description = autopilot.description?.trimmedOrNil {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    if let agent = assigneeAgent {
                        HStack(spacing: 4) {
                            ActorAvatar(name: agent.name, url: URL(string: agent.avatarUrl ?? ""), size: 14, isAgent: true)
                            Text(agent.name)
                                .font(.caption2.weight(.medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.secondary)
                    }
                    Text("·").foregroundStyle(.tertiary).font(.caption2)
                    Text(autopilot.executionMode.displayLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct AutopilotDetailView: View {
    let autopilot: Autopilot
    @Environment(AppState.self) private var app
    @State private var current: Autopilot
    @State private var triggers: [AutopilotTrigger] = []
    @State private var runs: [AutopilotRun] = []
    @State private var triggering = false

    init(autopilot: Autopilot) {
        self.autopilot = autopilot
        _current = State(initialValue: autopilot)
    }

    private var assigneeAgent: Agent? {
        app.agents.first { $0.id == current.assigneeId }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                actionRow
                if let description = current.description?.trimmedOrNil {
                    Text(description).font(.body).foregroundStyle(.secondary).textSelection(.enabled)
                }
                metadataCard
                if !triggers.isEmpty { triggersSection }
                if !runs.isEmpty { runsSection }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle(current.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sensoryFeedback(.success, trigger: runs.first?.id)
    }

    private var hero: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(current.statusEnum.tint.opacity(0.18))
                Image(systemName: current.statusEnum.systemImage)
                    .font(.title3)
                    .foregroundStyle(current.statusEnum.tint)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(current.title).font(.title3.weight(.bold))
                HStack(spacing: 6) {
                    Text(current.statusEnum.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(current.statusEnum.tint)
                    if let last = MulticaTime.relativeShort(from: current.lastRunAt) {
                        Text("·").foregroundStyle(.tertiary).font(.caption)
                        Text("Last run \(last)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                triggerNow()
            } label: {
                HStack(spacing: 6) {
                    if triggering {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text("Run now")
                }
            }
            .buttonStyle(PrimaryButtonStyle(isLoading: triggering))
            .disabled(triggering)

            Button {
                Task { _ = await app.setAutopilotStatus(current, status: current.isActive ? .paused : .active) }
            } label: {
                Label(current.isActive ? "Pause" : "Activate", systemImage: current.isActive ? "pause.fill" : "bolt.fill")
            }
            .buttonStyle(GhostButtonStyle())
        }
    }

    private var metadataCard: some View {
        VStack(spacing: 0) {
            row(icon: "bolt.fill", title: "Mode", value: AnyView(Text(current.executionMode.displayLabel).foregroundStyle(.secondary)))
            if let agent = assigneeAgent {
                Divider().padding(.leading, 14)
                HStack(spacing: 12) {
                    Image(systemName: "person.fill").foregroundStyle(.secondary).frame(width: 22)
                    Text("Assignee").font(.subheadline)
                    Spacer()
                    HStack(spacing: 5) {
                        ActorAvatar(name: agent.name, url: URL(string: agent.avatarUrl ?? ""), size: 18, isAgent: true)
                        Text(agent.name).font(.caption.weight(.semibold))
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            if let created = MulticaDate.mediumDate(current.createdAt) {
                Divider().padding(.leading, 14)
                row(icon: "calendar", title: "Created", value: AnyView(Text(created).foregroundStyle(.secondary)))
            }
            if let updated = MulticaDate.mediumDate(current.updatedAt) {
                Divider().padding(.leading, 14)
                row(icon: "clock", title: "Updated", value: AnyView(Text(updated).foregroundStyle(.secondary)))
            }
        }
        .cardSurface(padding: 0)
    }

    private func row(icon: String, title: LocalizedStringResource, value: AnyView) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 22)
            Text(title).font(.subheadline)
            Spacer()
            value.font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var triggersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Triggers (\(triggers.count))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(Array(triggers.enumerated()), id: \.element.id) { index, trigger in
                    triggerRow(trigger)
                    if index < triggers.count - 1 { Divider().padding(.leading, 14) }
                }
            }
            .cardSurface(padding: 0)
        }
    }

    private func triggerRow(_ trigger: AutopilotTrigger) -> some View {
        HStack(spacing: 12) {
            Image(systemName: trigger.kind == "schedule" ? "calendar" : (trigger.kind == "webhook" ? "antenna.radiowaves.left.and.right" : "terminal"))
                .foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(trigger.label ?? trigger.kind.displayLabel)
                    .font(.subheadline.weight(.medium))
                if let cron = trigger.cronExpression {
                    Text(cron).font(.caption2.monospaced()).foregroundStyle(.tertiary)
                } else if let next = MulticaDate.mediumDate(trigger.nextRunAt) {
                    Text("Next: \(next)").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Circle()
                .fill(trigger.enabled ? MulticaTheme.success : MulticaTheme.mutedForeground.opacity(0.5))
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var runsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent runs (\(runs.count))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(Array(runs.prefix(10).enumerated()), id: \.element.id) { index, run in
                    runRow(run)
                    if index < min(9, runs.count - 1) { Divider().padding(.leading, 14) }
                }
            }
            .cardSurface(padding: 0)
        }
    }

    private func runRow(_ run: AutopilotRun) -> some View {
        HStack(spacing: 12) {
            Image(systemName: run.statusEnum.systemImage)
                .foregroundStyle(run.statusEnum.tint)
                .symbolEffect(.pulse, isActive: run.statusEnum == .running)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(run.statusEnum.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(run.statusEnum.tint)
                HStack(spacing: 6) {
                    Text(run.source.displayLabel).font(.caption2).foregroundStyle(.tertiary)
                    if let relative = MulticaTime.relativeShort(from: run.triggeredAt) {
                        Text("·").foregroundStyle(.tertiary)
                        Text(relative).font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
            if let reason = run.failureReason, !reason.isEmpty {
                Image(systemName: "info.circle")
                    .foregroundStyle(MulticaTheme.danger)
                    .help(reason)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func load() async {
        if let updated = await app.loadAutopilotDetail(id: autopilot.id) {
            current = updated
        }
        triggers = app.autopilotTriggers(for: autopilot.id)
        runs = app.autopilotRuns(for: autopilot.id)
    }

    private func triggerNow() {
        triggering = true
        Task {
            _ = await app.triggerAutopilot(current)
            triggering = false
            await load()
        }
    }
}
