import SwiftUI

struct YouView: View {
    @Environment(AppState.self) private var app
    @State private var showingSignOutConfirm = false
    @State private var showingChangeServerConfirm = false
    @State private var showingWorkspaceSwitcher = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                profileCard
                workspaceCard
                serverCard
                aboutCard
                signOutButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("You")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "Sign out of Multica?",
            isPresented: $showingSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) { app.logout() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your token will be removed from this device.")
        }
        .confirmationDialog(
            "Change server?",
            isPresented: $showingChangeServerConfirm,
            titleVisibility: .visible
        ) {
            Button("Change", role: .destructive) { app.resetServerSetup() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This signs you out and lets you pick a different Multica server.")
        }
        .sheet(isPresented: $showingWorkspaceSwitcher) { WorkspaceSwitcherSheet() }
    }

    private var profileCard: some View {
        HStack(spacing: 14) {
            if let user = app.currentUser {
                ActorAvatar(name: user.name, url: URL(string: user.avatarUrl ?? ""), size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name).font(.body.weight(.semibold))
                    Text(user.email).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .cardSurface()
    }

    private var workspaceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Workspace")
            Button {
                showingWorkspaceSwitcher = true
            } label: {
                HStack(spacing: 12) {
                    if let workspace = app.selectedWorkspace {
                        WorkspaceAvatar(name: workspace.name, url: URL(string: workspace.avatarUrl ?? ""), size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workspace.name).font(.subheadline.weight(.semibold))
                            HStack(spacing: 6) {
                                Text(workspace.slug).font(.caption.monospaced()).foregroundStyle(.secondary)
                                if let prefix = workspace.issuePrefix {
                                    Text(prefix)
                                        .font(.caption2.monospaced().weight(.semibold))
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .foregroundStyle(MulticaTheme.brand)
                                        .background(MulticaTheme.brand.opacity(0.12), in: Capsule())
                                }
                            }
                        }
                    } else {
                        Text("No workspace selected").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                        .font(.caption.weight(.semibold))
                }
                .padding(14)
            }
            .buttonStyle(.plain)
            .cardSurface(padding: 0)
        }
    }

    private var serverCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Server")
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "server.rack").foregroundStyle(.secondary).frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(URL(string: app.serverURLString)?.host ?? app.serverURLString)
                            .font(.subheadline.monospaced())
                        Text("Connected").font(.caption2).foregroundStyle(MulticaTheme.success)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider().padding(.leading, 14)

                Button {
                    showingChangeServerConfirm = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.left.arrow.right").foregroundStyle(MulticaTheme.brand).frame(width: 22)
                        Text("Change server").font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            .cardSurface(padding: 0)
        }
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("About")
            VStack(spacing: 0) {
                row("Version", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—", icon: "info.circle")
                Divider().padding(.leading, 14)
                row("Build", Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—", icon: "hammer")
                Divider().padding(.leading, 14)
                Button {
                    Task { await app.refreshAll() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.clockwise").foregroundStyle(MulticaTheme.brand).frame(width: 22)
                        Text("Refresh data").font(.subheadline)
                        Spacer()
                        if app.isLoading { ProgressView().controlSize(.mini) }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            .cardSurface(padding: 0)
        }
    }

    private var signOutButton: some View {
        Button(role: .destructive) {
            showingSignOutConfirm = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign out").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(MulticaTheme.danger)
            .background(MulticaTheme.danger.opacity(0.10), in: RoundedRectangle(cornerRadius: MulticaTheme.radius, style: .continuous))
        }
        .padding(.top, 8)
    }

    private func sectionHeader(_ title: LocalizedStringResource) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
            .padding(.bottom, 8)
    }

    private func row(_ title: LocalizedStringResource, _ value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 22)
            Text(title).font(.subheadline)
            Spacer()
            Text(value).font(.caption.monospaced()).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
