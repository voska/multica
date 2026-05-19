import SwiftUI

enum AppTab: Hashable {
    case inbox, issues, agents, autopilots, you
}

@MainActor
@Observable
final class TabRouter {
    var selected: AppTab = .inbox
    var inboxPath: [InboxDestination] = []
    var issuesPath: [IssueDestination] = []
    var agentsPath: [AgentsDestination] = []
    var autopilotsPath: [AutopilotsDestination] = []
}

enum InboxDestination: Hashable {
    case event(InboxItem)
    case issue(Issue)
}
enum IssueDestination: Hashable {
    case issue(Issue)
}
enum AgentsDestination: Hashable {
    case agent(Agent)
    case squad(Squad)
}
enum AutopilotsDestination: Hashable {
    case autopilot(Autopilot)
}

struct MainTabsView: View {
    @Environment(AppState.self) private var app
    @State private var router = TabRouter()

    init() {
        #if DEBUG
        if let tab = ProcessInfo.processInfo.environment["MULTICA_TAB"] {
            let initial: AppTab
            switch tab {
            case "issues": initial = .issues
            case "agents": initial = .agents
            case "autopilots": initial = .autopilots
            case "you": initial = .you
            default: initial = .inbox
            }
            _router = State(initialValue: { let r = TabRouter(); r.selected = initial; return r }())
        }
        #endif
    }

    var body: some View {
        TabView(selection: $router.selected) {
            Tab(value: AppTab.inbox) { InboxTab() } label: {
                Label("Inbox", systemImage: "tray")
            }
            .badge(app.unreadInboxCount)

            Tab(value: AppTab.issues) { IssuesTab() } label: {
                Label("Issues", systemImage: "list.bullet")
            }
            .badge(app.openIssueCount)

            Tab(value: AppTab.agents) { AgentsTab() } label: {
                Label("Agents", systemImage: "bolt.circle")
            }

            Tab(value: AppTab.autopilots) { AutopilotsTab() } label: {
                Label("Autopilots", systemImage: "infinity")
            }

            Tab(value: AppTab.you) { YouTab() } label: {
                Label("You", systemImage: "person.circle")
            }
        }
        .tint(MulticaTheme.brand)
        .environment(router)
    }
}

private struct InboxTab: View {
    @Environment(TabRouter.self) private var router
    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.inboxPath) {
            InboxView()
                .navigationDestination(for: InboxDestination.self) { dest in
                    switch dest {
                    case .event(let item): InboxEventDetailView(item: item)
                    case .issue(let issue): IssueDetailView(issue: issue)
                    }
                }
        }
    }
}

private struct IssuesTab: View {
    @Environment(TabRouter.self) private var router
    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.issuesPath) {
            IssuesView()
                .navigationDestination(for: IssueDestination.self) { dest in
                    switch dest {
                    case .issue(let issue): IssueDetailView(issue: issue)
                    }
                }
        }
    }
}

private struct AgentsTab: View {
    @Environment(TabRouter.self) private var router
    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.agentsPath) {
            AgentsView()
                .navigationDestination(for: AgentsDestination.self) { dest in
                    switch dest {
                    case .agent(let agent): AgentDetailView(agent: agent)
                    case .squad(let squad): SquadDetailView(squad: squad)
                    }
                }
        }
    }
}

private struct AutopilotsTab: View {
    @Environment(TabRouter.self) private var router
    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.autopilotsPath) {
            AutopilotsView()
                .navigationDestination(for: AutopilotsDestination.self) { dest in
                    switch dest {
                    case .autopilot(let auto): AutopilotDetailView(autopilot: auto)
                    }
                }
        }
    }
}

private struct YouTab: View {
    var body: some View {
        NavigationStack { YouView() }
    }
}
