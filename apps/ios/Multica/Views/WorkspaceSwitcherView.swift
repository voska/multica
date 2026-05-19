import SwiftUI

struct WorkspaceSwitcherSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var app
    @State private var search = ""
    @State private var switching: String?

    private var filtered: [Workspace] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return app.workspaces }
        return app.workspaces.filter { w in
            w.name.localizedCaseInsensitiveContains(q)
                || w.slug.localizedCaseInsensitiveContains(q)
                || (w.issuePrefix ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if let user = app.currentUser {
                    Section {
                        HStack(spacing: 10) {
                            ActorAvatar(name: user.name, url: URL(string: user.avatarUrl ?? ""), size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name).font(.subheadline.weight(.semibold))
                                Text(user.email).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section {
                    if filtered.isEmpty {
                        ContentUnavailableView.search
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(filtered) { workspace in
                            Button {
                                Task { await switchTo(workspace) }
                            } label: {
                                WorkspaceRow(
                                    workspace: workspace,
                                    isSelected: workspace.id == app.selectedWorkspace?.id,
                                    isSwitching: workspace.id == switching
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Workspaces").textCase(nil).font(.caption).foregroundStyle(.secondary)
                }
            }
            .searchable(text: $search, prompt: "Search workspaces")
            .navigationTitle("Switch workspace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func switchTo(_ workspace: Workspace) async {
        if workspace.id == app.selectedWorkspace?.id { dismiss(); return }
        switching = workspace.id
        await app.selectWorkspace(workspace)
        switching = nil
        dismiss()
    }
}

struct WorkspaceRow: View {
    let workspace: Workspace
    let isSelected: Bool
    var isSwitching: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            WorkspaceAvatar(name: workspace.name, url: URL(string: workspace.avatarUrl ?? ""), size: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(workspace.name).font(.body.weight(.semibold))
                    if let prefix = workspace.issuePrefix, !prefix.isEmpty {
                        Text(prefix)
                            .font(.caption2.monospaced().weight(.semibold))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .foregroundStyle(MulticaTheme.brand)
                            .background(MulticaTheme.brand.opacity(0.12), in: Capsule())
                    }
                }
                Text(workspace.slug).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if isSwitching {
                ProgressView()
            } else if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(MulticaTheme.brand)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
