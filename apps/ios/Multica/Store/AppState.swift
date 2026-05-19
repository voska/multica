import Foundation
import Observation

enum AppPhase: Equatable {
    case launching
    case onboarding
    case authenticating
    case ready
}

@MainActor
@Observable
final class AppState {
    static let defaultServerURL = "https://app.multica.ai"

    // Auth + server
    var serverURLString: String
    var didCompleteServerSetup: Bool
    var token: String?
    var currentUser: User?

    // Workspaces
    var workspaces: [Workspace] = []
    var selectedWorkspace: Workspace?

    // Domain data
    var issues: [Issue] = []
    var openIssueCount = 0
    var inbox: [InboxItem] = []
    var unreadInboxCount = 0
    var agents: [Agent] = []
    var projects: [Project] = []
    var squads: [Squad] = []
    var autopilots: [Autopilot] = []

    // Detail caches
    @ObservationIgnored private var squadMembersCache: [String: [SquadMember]] = [:]
    @ObservationIgnored private var projectResourcesCache: [String: [ProjectResource]] = [:]
    @ObservationIgnored private var autopilotTriggersCache: [String: [AutopilotTrigger]] = [:]
    @ObservationIgnored private var autopilotRunsCache: [String: [AutopilotRun]] = [:]

    // Status
    var isBootstrapping = false
    var isLoading = false
    var lastError: String?

    @ObservationIgnored private let tokenStore: any TokenStoring
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var loadingDepth = 0
    @ObservationIgnored private var hasBootstrappedOnce = false
    @ObservationIgnored private var skipNetworkBootstrap = false

    init(defaults: UserDefaults = .standard, tokenStore: any TokenStoring = KeychainStore(service: "ai.multica.mobile")) {
        self.defaults = defaults
        self.tokenStore = tokenStore
        let storedURL = defaults.string(forKey: "serverURL") ?? Self.defaultServerURL
        self.serverURLString = Self.normalizedServerURL(storedURL) ?? Self.defaultServerURL
        self.didCompleteServerSetup = defaults.bool(forKey: "didCompleteServerSetup")
        self.token = try? tokenStore.read(account: Self.tokenAccountName(for: self.serverURLString))
    }

    // MARK: - Phase

    var isConfigured: Bool { Self.normalizedServerURL(serverURLString) != nil && didCompleteServerSetup }
    var isAuthenticated: Bool { token != nil && currentUser != nil }

    var phase: AppPhase {
        if isBootstrapping && !hasBootstrappedOnce { return .launching }
        if !isConfigured || token == nil { return .onboarding }
        if currentUser == nil { return .authenticating }
        return .ready
    }

    var api: APIClient? {
        guard let url = URL(string: serverURLString) else { return nil }
        return APIClient(baseURL: url, token: token, workspaceID: selectedWorkspace?.id)
    }

    // MARK: - Server setup

    @discardableResult
    func saveServerURL(_ raw: String) -> Bool {
        guard let normalized = Self.normalizedServerURL(raw) else {
            lastError = "Enter a valid HTTPS Multica server URL."
            return false
        }
        let oldAccount = Self.tokenAccountName(for: serverURLString)
        let oldURL = serverURLString
        serverURLString = normalized
        didCompleteServerSetup = true
        defaults.set(normalized, forKey: "serverURL")
        defaults.set(true, forKey: "didCompleteServerSetup")
        if oldURL != normalized {
            clearSession(deleteAccount: oldAccount)
        }
        return true
    }

    func resetServerSetup() {
        clearSession(deleteAccount: Self.tokenAccountName(for: serverURLString))
        didCompleteServerSetup = false
        defaults.set(false, forKey: "didCompleteServerSetup")
    }

    // MARK: - Auth

    func restoreAndBootstrap() async {
        guard !isBootstrapping else { return }
        if skipNetworkBootstrap { hasBootstrappedOnce = true; return }
        isBootstrapping = true
        defer {
            isBootstrapping = false
            hasBootstrappedOnce = true
        }
        if token != nil {
            await bootstrap()
        }
    }

    @discardableResult
    func sendCode(email: String) async -> Bool {
        await performReturning {
            try await requireAPI().sendCode(email: email)
            return true
        } ?? false
    }

    @discardableResult
    func verifyCode(email: String, code: String) async -> Bool {
        await performReturning {
            let response = try await requireAPI().verifyCode(email: email, code: code)
            try storeAuthenticatedToken(response.token)
            currentUser = response.user
            await bootstrap()
            return true
        } ?? false
    }

    @discardableResult
    func useManualToken(_ value: String) async -> Bool {
        guard let validated = Self.validatedManualToken(value) else {
            lastError = "Paste a non-empty bearer token."
            return false
        }
        return await performReturning {
            try storeAuthenticatedToken(validated)
            await bootstrap()
            return true
        } ?? false
    }

    func bootstrap() async {
        await perform {
            let client = try requireAPI()
            currentUser = try await client.getMe()
            workspaces = try await client.listWorkspaces()
            let preferredWorkspaceID = selectedWorkspace?.id ?? defaults.string(forKey: "selectedWorkspaceID")
            if let preferredWorkspaceID, let preferred = workspaces.first(where: { $0.id == preferredWorkspaceID }) {
                selectedWorkspace = preferred
            } else if selectedWorkspace == nil || !workspaces.contains(where: { $0.id == selectedWorkspace?.id }) {
                selectedWorkspace = workspaces.first
            }
            if let selectedWorkspace { defaults.set(selectedWorkspace.id, forKey: "selectedWorkspaceID") }
            await refreshAll()
        }
    }

    // MARK: - Workspace

    func selectWorkspace(_ workspace: Workspace, refresh: Bool = true) async {
        selectedWorkspace = workspace
        defaults.set(workspace.id, forKey: "selectedWorkspaceID")
        if refresh { await refreshAll() }
    }

    func refreshAll() async {
        guard let workspaceID = selectedWorkspace?.id else { return }
        await perform {
            let client = try requireAPI()
            async let issueResponse = client.listIssues(workspaceID: workspaceID)
            async let openIssueResponse = client.listIssues(workspaceID: workspaceID, openOnly: true)
            async let inboxItems = client.listInbox()
            async let unreadCount = client.getUnreadInboxCount()
            async let agentItems = client.listAgents(workspaceID: workspaceID)
            async let projectResponse = client.listProjects(workspaceID: workspaceID)
            async let squadItems = client.listSquads()
            async let autopilotResponse = client.listAutopilots()
            let loadedIssues = try await issueResponse.issues
            issues = loadedIssues
            openIssueCount = try await openIssueResponse.total ?? loadedIssues.filter { $0.isOpen }.count
            inbox = try await inboxItems.filter { $0.workspaceId == workspaceID && !$0.archived }
            unreadInboxCount = try await unreadCount.count
            agents = try await agentItems
            projects = try await projectResponse.projects
            squads = try await squadItems.filter { $0.workspaceId == nil || $0.workspaceId == workspaceID }
            autopilots = try await autopilotResponse.autopilots
        }
    }

    // MARK: - Autopilots

    func autopilotTriggers(for id: String) -> [AutopilotTrigger] { autopilotTriggersCache[id] ?? [] }
    func autopilotRuns(for id: String) -> [AutopilotRun] { autopilotRunsCache[id] ?? [] }

    func loadAutopilotDetail(id: String) async -> Autopilot? {
        await performReturning {
            let client = try requireAPI()
            async let detail = client.getAutopilot(id)
            async let runs = client.listAutopilotRuns(id)
            let result = try await (detail, runs)
            if let index = autopilots.firstIndex(where: { $0.id == id }) {
                autopilots[index] = result.0.autopilot
            }
            autopilotTriggersCache[id] = result.0.triggers
            autopilotRunsCache[id] = result.1.runs
            return result.0.autopilot
        }
    }

    func setAutopilotStatus(_ autopilot: Autopilot, status: AutopilotStatus) async -> Autopilot? {
        await performReturning {
            let updated = try await requireAPI().updateAutopilot(
                autopilot.id,
                payload: UpdateAutopilotPayload(
                    title: nil, description: nil, assigneeId: nil,
                    status: status.rawValue, executionMode: nil, issueTitleTemplate: nil
                )
            )
            if let index = autopilots.firstIndex(where: { $0.id == autopilot.id }) {
                autopilots[index] = updated
            }
            return updated
        }
    }

    @discardableResult
    func triggerAutopilot(_ autopilot: Autopilot) async -> AutopilotRun? {
        await performReturning {
            let run = try await requireAPI().triggerAutopilot(autopilot.id)
            var runs = autopilotRunsCache[autopilot.id] ?? []
            runs.insert(run, at: 0)
            autopilotRunsCache[autopilot.id] = runs
            return run
        }
    }

    // MARK: - Detail caches

    func squadMembers(for squadID: String) -> [SquadMember] { squadMembersCache[squadID] ?? [] }
    func projectResources(for projectID: String) -> [ProjectResource] { projectResourcesCache[projectID] ?? [] }

    func loadSquadDetail(squadID: String) async -> Squad? {
        await performReturning {
            let client = try requireAPI()
            async let freshSquad = client.getSquad(squadID)
            async let loadedMembers = client.listSquadMembers(squadID: squadID)
            let result = try await (freshSquad, loadedMembers)
            if let index = squads.firstIndex(where: { $0.id == squadID }) { squads[index] = result.0 }
            squadMembersCache[squadID] = result.1
            return result.0
        }
    }

    func loadProjectDetail(projectID: String) async -> Project? {
        await performReturning {
            let client = try requireAPI()
            async let freshProject = client.getProject(projectID)
            async let loadedResources = client.listProjectResources(projectID: projectID)
            let result = try await (freshProject, loadedResources)
            if let index = projects.firstIndex(where: { $0.id == projectID }) { projects[index] = result.0 }
            projectResourcesCache[projectID] = result.1.resources
            return result.0
        }
    }

    // MARK: - Mutations

    @discardableResult
    func createProject(title: String, description: String, icon: String, status: ProjectStatus, priority: IssuePriority) async -> Project? {
        await performReturning {
            let project = try await requireAPI().createProject(CreateProjectPayload(
                title: title,
                description: description.trimmedOrNil,
                icon: icon.trimmedOrNil,
                status: status.rawValue,
                priority: priority.rawValue,
                leadType: nil,
                leadId: nil
            ))
            projects.insert(project, at: 0)
            return project
        }
    }

    func updateProject(_ project: Project, status: ProjectStatus? = nil, priority: IssuePriority? = nil) async -> Project? {
        await performReturning {
            let updated = try await requireAPI().updateProject(
                project.id,
                payload: UpdateProjectPayload(title: nil, description: nil, icon: nil, status: status?.rawValue, priority: priority?.rawValue, leadType: nil, leadId: nil)
            )
            if let index = projects.firstIndex(where: { $0.id == project.id }) { projects[index] = updated }
            return updated
        }
    }

    @discardableResult
    func createIssue(title: String, description: String, priority: IssuePriority) async -> Issue? {
        guard let workspaceID = selectedWorkspace?.id else {
            lastError = "Select a workspace before creating an issue."
            return nil
        }
        return await performReturning {
            let issue = try await requireAPI().createIssue(CreateIssuePayload(
                workspaceId: workspaceID,
                title: title,
                description: description.trimmedOrNil,
                status: IssueStatus.todo.rawValue,
                priority: priority.rawValue,
                assigneeType: nil,
                assigneeId: nil
            ))
            issues.insert(issue, at: 0)
            if issue.isOpen { openIssueCount += 1 }
            return issue
        }
    }

    func updateIssue(_ issue: Issue, status: IssueStatus? = nil, priority: IssuePriority? = nil) async -> Issue? {
        await performReturning {
            let updated = try await requireAPI().updateIssue(
                issue.id,
                payload: UpdateIssuePayload(title: nil, description: nil, status: status?.rawValue, priority: priority?.rawValue, assigneeType: nil, assigneeId: nil)
            )
            if let index = issues.firstIndex(where: { $0.id == issue.id }) { issues[index] = updated }
            let wasOpen = issue.isOpen
            let isOpenNow = updated.isOpen
            if wasOpen != isOpenNow {
                openIssueCount = max(0, openIssueCount + (isOpenNow ? 1 : -1))
            }
            return updated
        }
    }

    func loadIssueDetail(issueID: String) async -> (issue: Issue, comments: [Comment])? {
        await performReturning {
            let client = try requireAPI()
            async let freshIssue = client.getIssue(issueID)
            async let loadedComments = client.listComments(issueID: issueID)
            return try await (freshIssue, loadedComments)
        }
    }

    func createComment(issueID: String, content: String) async -> Comment? {
        await performReturning {
            try await requireAPI().createComment(issueID: issueID, content: content)
        }
    }

    func markInboxRead(_ item: InboxItem) async {
        await perform {
            let updated = try await requireAPI().markInboxRead(item.id)
            if let index = inbox.firstIndex(where: { $0.id == item.id }) { inbox[index] = updated }
            unreadInboxCount = inbox.filter { !$0.read }.count
        }
    }

    func archiveInbox(_ item: InboxItem) async {
        await perform {
            _ = try await requireAPI().archiveInbox(item.id)
            inbox.removeAll { $0.id == item.id }
            unreadInboxCount = inbox.filter { !$0.read }.count
        }
    }

    func logout() {
        let client = api
        clearSession(deleteAccount: Self.tokenAccountName(for: serverURLString))
        Task { try? await client?.logout() }
    }

    func clearError() { lastError = nil }

    // MARK: - Statics

    static func normalizedServerURL(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if !value.contains("://") { value = "https://" + value }
        while value.hasSuffix("/") { value.removeLast() }
        guard let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              let host = components.host,
              !host.isEmpty,
              host.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              (host == "localhost" || host.contains("."))
        else { return nil }
        return components.url?.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static func tokenAccountName(for serverURL: String) -> String {
        guard let url = URL(string: serverURL), let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased() else { return "token@invalid" }
        let port = url.port.map { ":\($0)" } ?? ""
        return "token@\(scheme)://\(host)\(port)"
    }

    static func validatedManualToken(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    #if DEBUG
    func setTokenForTesting(_ value: String) { try? storeAuthenticatedToken(value) }

    /// Seeds the store with mock data so the post-auth UI can be inspected
    /// in the simulator without a live server. Triggered by setting the
    /// MULTICA_MOCK environment variable to "1".
    func seedMockForPreview() {
        token = "mock-token"
        currentUser = User(
            id: "u1", name: "Matt Voska", email: "matt@voska.org",
            avatarUrl: nil, createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z"
        )
        workspaces = [
            Workspace(id: "w1", name: "Acme HQ", slug: "acme-hq", description: nil,
                      issuePrefix: "ACM", avatarUrl: nil,
                      createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z"),
            Workspace(id: "w2", name: "Voska Labs", slug: "voska", description: nil,
                      issuePrefix: "VOS", avatarUrl: nil,
                      createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z")
        ]
        selectedWorkspace = workspaces.first
        openIssueCount = 7
        unreadInboxCount = 3
        let now = ISO8601DateFormatter().string(from: Date())
        agents = [
            Agent(id: "a1", workspaceId: "w1", runtimeId: nil, name: "FixerBot",
                  description: "Autonomous bug fixer", avatarUrl: nil,
                  runtimeMode: "cloud", visibility: "workspace", status: "working",
                  model: "claude-opus-4-7", ownerId: "u1", createdAt: now, updatedAt: now, archivedAt: nil),
            Agent(id: "a2", workspaceId: "w1", runtimeId: nil, name: "ReviewBot",
                  description: "Reviews PRs against the spec", avatarUrl: nil,
                  runtimeMode: "cloud", visibility: "workspace", status: "online",
                  model: "claude-sonnet-4-6", ownerId: "u1", createdAt: now, updatedAt: now, archivedAt: nil),
            Agent(id: "a3", workspaceId: "w1", runtimeId: nil, name: "ArchiveBot",
                  description: nil, avatarUrl: nil,
                  runtimeMode: "cloud", visibility: "workspace", status: "offline",
                  model: "claude-haiku-4-5", ownerId: "u1", createdAt: now, updatedAt: now, archivedAt: nil)
        ]
        issues = [
            Issue(id: "i1", workspaceId: "w1", number: 42, identifier: "ACM-42",
                  title: "Cold-start crash on iOS 18 launch", description: "Repro steps in body…",
                  status: "in_progress", priority: "urgent",
                  assigneeType: "agent", assigneeId: "a1", creatorType: "member", creatorId: "u1",
                  parentIssueId: nil, projectId: nil, startDate: nil, dueDate: nil, labels: nil,
                  createdAt: now, updatedAt: now),
            Issue(id: "i2", workspaceId: "w1", number: 41, identifier: "ACM-41",
                  title: "OAuth callback path returns 404", description: nil,
                  status: "in_review", priority: "high",
                  assigneeType: "member", assigneeId: "u1", creatorType: "member", creatorId: "u1",
                  parentIssueId: nil, projectId: nil, startDate: nil, dueDate: nil, labels: nil,
                  createdAt: now, updatedAt: now),
            Issue(id: "i3", workspaceId: "w1", number: 40, identifier: "ACM-40",
                  title: "Tighten typing on agent runtime status", description: nil,
                  status: "todo", priority: "medium",
                  assigneeType: nil, assigneeId: nil, creatorType: "member", creatorId: "u1",
                  parentIssueId: nil, projectId: nil, startDate: nil, dueDate: nil, labels: nil,
                  createdAt: now, updatedAt: now),
            Issue(id: "i4", workspaceId: "w1", number: 39, identifier: "ACM-39",
                  title: "Investigate rate-limit on Anthropic endpoints", description: nil,
                  status: "blocked", priority: "high",
                  assigneeType: "agent", assigneeId: "a2", creatorType: "member", creatorId: "u1",
                  parentIssueId: nil, projectId: nil, startDate: nil, dueDate: nil, labels: nil,
                  createdAt: now, updatedAt: now)
        ]
        inbox = [
            InboxItem(id: "n1", workspaceId: "w1", type: "agent_completed", severity: "success",
                      issueId: "i1", title: "FixerBot completed ACM-42",
                      body: "Posted PR with the fix and assigned to you for review.",
                      issueStatus: "in_review", read: false, archived: false, createdAt: now),
            InboxItem(id: "n2", workspaceId: "w1", type: "agent_blocked", severity: "warning",
                      issueId: "i4", title: "ReviewBot is blocked on ACM-39",
                      body: "Rate limited by upstream. Will retry in 5 minutes.",
                      issueStatus: nil, read: false, archived: false, createdAt: now),
            InboxItem(id: "n3", workspaceId: "w1", type: "mention", severity: "info",
                      issueId: "i2", title: "You were mentioned on ACM-41",
                      body: "Could you take a look at the redirect path?",
                      issueStatus: nil, read: true, archived: false,
                      createdAt: "2026-05-17T08:30:00Z")
        ]
        squads = [
            Squad(id: "s1", workspaceId: "w1", name: "iOS strike team",
                  description: "Native iOS work — shipping the mobile client.",
                  instructions: nil, avatarUrl: nil,
                  leaderId: "a1", creatorId: "u1",
                  createdAt: now, updatedAt: now, archivedAt: nil, archivedBy: nil)
        ]
        skipNetworkBootstrap = true
        autopilots = [
            Autopilot(id: "ap1", workspaceId: "w1", title: "Daily PR triage",
                      description: "Sweep open PRs each morning and surface attention items.",
                      assigneeId: "a2", status: "active", executionMode: "create_issue",
                      issueTitleTemplate: nil, createdByType: "member", createdById: "u1",
                      lastRunAt: now, createdAt: now, updatedAt: now),
            Autopilot(id: "ap2", workspaceId: "w1", title: "Weekly dependency audit",
                      description: nil,
                      assigneeId: "a2", status: "paused", executionMode: "run_only",
                      issueTitleTemplate: nil, createdByType: "member", createdById: "u1",
                      lastRunAt: "2026-05-10T08:00:00Z", createdAt: now, updatedAt: now)
        ]
        hasBootstrappedOnce = true
    }
    #endif

    // MARK: - Internals

    private func requireAPI() throws -> APIClient {
        guard let api else { throw APIClient.APIError.invalidURL(serverURLString) }
        return api
    }

    private func storeAuthenticatedToken(_ value: String) throws {
        token = value
        try tokenStore.save(value, account: Self.tokenAccountName(for: serverURLString))
    }

    private func clearSession(deleteAccount: String) {
        token = nil
        currentUser = nil
        workspaces = []
        selectedWorkspace = nil
        issues = []
        openIssueCount = 0
        inbox = []
        unreadInboxCount = 0
        agents = []
        projects = []
        squads = []
        autopilots = []
        squadMembersCache = [:]
        projectResourcesCache = [:]
        autopilotTriggersCache = [:]
        autopilotRunsCache = [:]
        defaults.removeObject(forKey: "selectedWorkspaceID")
        tokenStore.delete(account: deleteAccount)
    }

    private func perform(_ operation: () async throws -> Void) async {
        beginLoading()
        defer { endLoading() }
        lastError = nil
        do { try await operation() } catch { handle(error) }
    }

    private func performReturning<T>(_ operation: () async throws -> T) async -> T? {
        beginLoading()
        defer { endLoading() }
        lastError = nil
        do { return try await operation() } catch {
            handle(error)
            return nil
        }
    }

    private func beginLoading() {
        loadingDepth += 1
        isLoading = true
    }

    private func endLoading() {
        loadingDepth = max(0, loadingDepth - 1)
        isLoading = loadingDepth > 0
    }

    private func handle(_ error: Error) {
        if case APIClient.APIError.unauthorized(let message) = error {
            clearSession(deleteAccount: Self.tokenAccountName(for: serverURLString))
            lastError = message.isEmpty ? "Your session expired. Please sign in again." : message
        } else {
            lastError = error.localizedDescription
        }
    }
}

extension String {
    var trimmedOrNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
