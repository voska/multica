import SwiftUI

enum IssueScope: String, CaseIterable, Identifiable {
    case open, mine, agents, all
    var id: String { rawValue }
    var title: LocalizedStringResource {
        switch self {
        case .open: "Open"
        case .mine: "Mine"
        case .agents: "Agents"
        case .all: "All"
        }
    }
}

enum IssueGrouping: String, CaseIterable, Identifiable {
    case status, priority, none
    var id: String { rawValue }
    var title: LocalizedStringResource {
        switch self {
        case .status: "Group by status"
        case .priority: "Group by priority"
        case .none: "No grouping"
        }
    }
    var systemImage: String {
        switch self {
        case .status: "circle.lefthalf.filled"
        case .priority: "flag"
        case .none: "list.bullet"
        }
    }
}

struct IssuesView: View {
    @Environment(AppState.self) private var app
    @State private var scope: IssueScope = .open
    @State private var grouping: IssueGrouping = .status
    @State private var search = ""
    @State private var showingCreate = false

    private var filtered: [Issue] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return app.issues.filter { issue in
            let scopeMatches: Bool = {
                switch scope {
                case .open: return issue.isOpen
                case .all: return true
                case .mine: return issue.assigneeId == app.currentUser?.id || issue.creatorId == app.currentUser?.id
                case .agents: return issue.assigneeType == "agent"
                }
            }()
            let searchMatches = q.isEmpty
                || issue.title.lowercased().contains(q)
                || (issue.identifier?.lowercased().contains(q) ?? false)
                || (issue.description?.lowercased().contains(q) ?? false)
            return scopeMatches && searchMatches
        }
    }

    private var groupedByStatus: [(IssueStatus, [Issue])] {
        let groups = Dictionary(grouping: filtered, by: \.statusEnum)
        return IssueStatus.openOrder.compactMap { status in
            guard let items = groups[status], !items.isEmpty else { return nil }
            return (status, items.sorted { $0.priorityEnum.rank < $1.priorityEnum.rank })
        } + IssueStatus.workflowOrder
            .filter { !IssueStatus.openOrder.contains($0) }
            .compactMap { status in
                guard let items = groups[status], !items.isEmpty else { return nil }
                return (status, items.sorted { ($0.updatedAt ?? "") > ($1.updatedAt ?? "") })
            }
    }

    private var groupedByPriority: [(IssuePriority, [Issue])] {
        let groups = Dictionary(grouping: filtered, by: \.priorityEnum)
        return IssuePriority.allCases.compactMap { priority in
            guard let items = groups[priority], !items.isEmpty else { return nil }
            return (priority, items.sorted { ($0.updatedAt ?? "") > ($1.updatedAt ?? "") })
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Scope", selection: $scope) {
                    ForEach(IssueScope.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if filtered.isEmpty {
                Section {
                    EmptyState(
                        title: scope == .open ? "All clear" : "No issues",
                        message: scope == .open
                            ? "No open issues match this filter."
                            : "Nothing matches this filter.",
                        systemImage: "checkmark.circle"
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            } else {
                switch grouping {
                case .status: statusSections
                case .priority: prioritySections
                case .none: flatSection
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Issues")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Grouping", selection: $grouping) {
                        ForEach(IssueGrouping.allCases) {
                            Label($0.title, systemImage: $0.systemImage).tag($0)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Sort and group")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreate = true
                } label: { Image(systemName: "square.and.pencil") }
                .accessibilityLabel("New issue")
            }
        }
        .searchable(text: $search, prompt: "Search issues")
        .refreshable { await app.refreshAll() }
        .sheet(isPresented: $showingCreate) { CreateIssueSheet() }
        .sensoryFeedback(.selection, trigger: scope)
        .sensoryFeedback(.selection, trigger: grouping)
    }

    @ViewBuilder private var statusSections: some View {
        ForEach(groupedByStatus, id: \.0) { group in
            Section {
                ForEach(group.1) { issue in
                    issueLink(issue)
                }
            } header: {
                groupHeader(systemImage: group.0.rawValue, tint: group.0.tint) {
                    HStack(spacing: 6) {
                        IssueStatusIcon(status: group.0, size: 12)
                        Text(group.0.title).font(.caption.weight(.semibold))
                        Spacer()
                        Text("\(group.1.count)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                }
            }
        }
    }

    @ViewBuilder private var prioritySections: some View {
        ForEach(groupedByPriority, id: \.0) { group in
            Section {
                ForEach(group.1) { issue in
                    issueLink(issue)
                }
            } header: {
                groupHeader(systemImage: group.0.systemImage, tint: group.0.tint) {
                    HStack(spacing: 6) {
                        Image(systemName: group.0.systemImage).foregroundStyle(group.0.tint).imageScale(.small)
                        Text(group.0.title).font(.caption.weight(.semibold))
                        Spacer()
                        Text("\(group.1.count)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                }
            }
        }
    }

    @ViewBuilder private var flatSection: some View {
        Section {
            ForEach(filtered.sorted { ($0.updatedAt ?? "") > ($1.updatedAt ?? "") }) { issue in
                issueLink(issue)
            }
        }
    }

    private func groupHeader<Content: View>(systemImage: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        content()
            .foregroundStyle(.primary)
            .textCase(nil)
    }

    @ViewBuilder private func issueLink(_ issue: Issue) -> some View {
        NavigationLink(value: IssueDestination.issue(issue)) {
            IssueRow(issue: issue)
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                Task { await app.updateIssue(issue, status: .done) }
            } label: { Label("Done", systemImage: "checkmark.circle.fill") }
            .tint(MulticaTheme.info)
        }
        .swipeActions(edge: .leading) {
            Button {
                Task { await app.updateIssue(issue, status: .inProgress) }
            } label: { Label("Start", systemImage: "play.fill") }
            .tint(MulticaTheme.warning)
        }
        .contextMenu {
            Menu("Status") {
                ForEach(IssueStatus.workflowOrder) { status in
                    Button {
                        Task { await app.updateIssue(issue, status: status) }
                    } label: { Label(status.title, systemImage: "circle") }
                }
            }
            Menu("Priority") {
                ForEach(IssuePriority.allCases) { priority in
                    Button {
                        Task { await app.updateIssue(issue, priority: priority) }
                    } label: { Label(priority.title, systemImage: priority.systemImage) }
                }
            }
        }
    }
}

struct IssueRow: View {
    let issue: Issue

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            IssueStatusIcon(status: issue.statusEnum, size: 16)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if let identifier = issue.identifier {
                        Text(identifier)
                            .font(.caption2.monospaced().weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    Text(issue.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                if issue.description?.isEmpty == false {
                    Text(issue.description ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    PriorityChip(priority: issue.priorityEnum)
                    if let relative = MulticaTime.relativeShort(from: issue.updatedAt ?? issue.createdAt) {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .imageScale(.small)
                            Text(relative)
                                .monospacedDigit()
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(issue.identifier ?? "Issue"). \(issue.title). \(String(localized: issue.statusEnum.title)). \(String(localized: issue.priorityEnum.title))"))
    }
}

struct CreateIssueSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var app
    @State private var title = ""
    @State private var description = ""
    @State private var priority: IssuePriority = .medium
    @State private var submitting = false
    @State private var inlineError: String?
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Issue title", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.title3)
                        .focused($titleFocused)
                    Picker(selection: $priority) {
                        ForEach(IssuePriority.allCases) { value in
                            Label {
                                Text(value.title).foregroundStyle(value.tint)
                            } icon: {
                                Image(systemName: value.systemImage).foregroundStyle(value.tint)
                            }
                            .tag(value)
                        }
                    } label: {
                        Label("Priority", systemImage: priority.systemImage)
                    }
                }
                Section("Description") {
                    TextField("What needs to happen?", text: $description, axis: .vertical)
                        .lineLimit(4...12)
                }
                if let inlineError { Section { InlineError(message: inlineError) } }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { submit() } label: {
                        if submitting { ProgressView().controlSize(.small) } else { Text("Create").fontWeight(.semibold) }
                    }
                    .disabled(title.trimmedOrNil == nil || submitting)
                }
            }
            .onAppear { titleFocused = true }
        }
    }

    private func submit() {
        submitting = true
        inlineError = nil
        Task {
            let issue = await app.createIssue(title: title, description: description, priority: priority)
            submitting = false
            if issue != nil {
                dismiss()
            } else {
                inlineError = app.lastError ?? "Could not create issue."
                app.clearError()
            }
        }
    }
}
