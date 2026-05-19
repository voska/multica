import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ZStack {
            switch app.phase {
            case .launching:
                LoadingScreen(message: "Connecting to Multica…")
            case .onboarding:
                OnboardingFlow()
                    .transition(.opacity)
            case .authenticating:
                AuthenticatingScreen()
                    .transition(.opacity)
            case .ready:
                if app.workspaces.isEmpty {
                    NoWorkspacesScreen()
                        .transition(.opacity)
                } else {
                    MainTabsView()
                        .transition(.opacity)
                }
            }
        }
        .task { await app.restoreAndBootstrap() }
        .overlay(alignment: .top) {
            if let error = app.lastError, app.phase == .ready {
                ErrorBanner(message: error) { app.clearError() }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: app.lastError)
        .animation(.snappy, value: app.phase)
    }
}

private struct AuthenticatingScreen: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(spacing: 16) {
            ProgressView("Restoring session…").controlSize(.large)
            if app.lastError != nil {
                Text("Could not restore this session.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Sign out", role: .destructive) { app.logout() }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .task { await app.bootstrap() }
    }
}

private struct NoWorkspacesScreen: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ContentUnavailableView {
            Label("No workspaces", systemImage: "square.grid.2x2")
        } description: {
            Text("This account is signed in, but no Multica workspaces are available.")
        } actions: {
            Button("Sign out", role: .destructive) { app.logout() }
                .buttonStyle(.borderedProminent)
        }
    }
}

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message).font(.callout).lineLimit(3)
            Spacer(minLength: 8)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Dismiss error")
        }
        .padding(12)
        .foregroundStyle(.white)
        .background(MulticaTheme.danger.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
        .accessibilityElement(children: .combine)
    }
}
