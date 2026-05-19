import SwiftUI

enum OnboardingStep: Hashable {
    case serverPicker
    case signInMethod
    case emailEntry
    case verifyCode(email: String)
    case tokenEntry
}

struct OnboardingFlow: View {
    @Environment(AppState.self) private var app
    @State private var path: [OnboardingStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeStep { startFlow() }
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .serverPicker:
                        ServerPickerStep { path.append(.signInMethod) }
                    case .signInMethod:
                        SignInMethodStep { method in
                            switch method {
                            case .email: path.append(.emailEntry)
                            case .token: path.append(.tokenEntry)
                            }
                        }
                    case .emailEntry:
                        EmailEntryStep { email in path.append(.verifyCode(email: email)) }
                    case .verifyCode(let email):
                        VerifyCodeStep(email: email)
                    case .tokenEntry:
                        TokenEntryStep()
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            if app.didCompleteServerSetup && app.token == nil {
                path = [.signInMethod]
            }
        }
    }

    private func startFlow() {
        if app.didCompleteServerSetup {
            path = [.signInMethod]
        } else {
            path = [.serverPicker]
        }
    }
}

// MARK: - Step 0: Welcome

private struct WelcomeStep: View {
    let onContinue: () -> Void
    @Environment(AppState.self) private var app

    var body: some View {
        OnboardingScreen(step: 0, total: 4, hideBack: true) {
            VStack(spacing: 24) {
                OnboardingHero(
                    systemImage: "sparkles.rectangle.stack.fill",
                    title: "Welcome to Multica",
                    subtitle: "Manage agents, issues, squads, and autopilot from a native iOS client."
                )
                FeatureList(items: [
                    .init(icon: "checklist", title: "Issues, organized", text: "Triage, prioritize, and act on issues with native gestures."),
                    .init(icon: "person.2.wave.2", title: "Agents at hand", text: "Inspect agents, squads, and runs on the go."),
                    .init(icon: "bolt.horizontal.fill", title: "Autopilot insight", text: "See every automated event with rich context.")
                ])
                .padding(.top, 8)
            }
        } footer: {
            Button(action: onContinue) {
                Label("Get started", systemImage: "arrow.right")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("onboarding.welcome.continue")
        }
    }
}

private struct FeatureList: View {
    struct Feature: Identifiable {
        let id = UUID()
        let icon: String
        let title: LocalizedStringResource
        let text: LocalizedStringResource
    }
    let items: [Feature]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(MulticaTheme.brand.opacity(0.12))
                        Image(systemName: item.icon).foregroundStyle(MulticaTheme.brand)
                    }
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.subheadline.weight(.semibold))
                        Text(item.text).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - Step 1: Server picker

private struct ServerPickerStep: View {
    @Environment(AppState.self) private var app
    let onContinue: () -> Void

    @State private var customURL = ""
    @State private var inlineError: String?
    @State private var showCustom = false

    private var presets: [Preset] {
        [
            Preset(name: "Multica Cloud", subtitle: "The hosted Multica.", url: AppState.defaultServerURL, systemImage: "cloud.fill"),
            Preset(name: "Matt's Multica", subtitle: "Personal self-hosted server.", url: "https://agents.l.voska.org", systemImage: "server.rack")
        ]
    }

    var body: some View {
        OnboardingScreen(step: 1, total: 4) {
            OnboardingHero(systemImage: "network", title: "Choose your server", subtitle: "Multica works with the cloud or any compatible self-hosted server.")
            VStack(spacing: 12) {
                ForEach(presets) { preset in
                    Button { select(preset.url) } label: {
                        PresetRow(preset: preset, isSelected: app.serverURLString == preset.url)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("onboarding.server.preset.\(preset.url)")
                }
                Button {
                    withAnimation(.snappy) { showCustom.toggle() }
                } label: {
                    Label(showCustom ? "Hide custom server" : "Use a custom server", systemImage: "globe")
                        .font(.callout.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .foregroundStyle(MulticaTheme.brand)

                if showCustom {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Server URL").font(.subheadline.weight(.semibold))
                        TextField("https://multica.example.com", text: $customURL)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textContentType(.URL)
                            .submitLabel(.go)
                            .onSubmit(submitCustom)
                            .accessibilityIdentifier("onboarding.server.custom")
                        if let inlineError {
                            InlineError(message: inlineError)
                        } else {
                            Text("Must be HTTPS. Tokens are scoped per host.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .cardSurface()
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        } footer: {
            Button(action: submitCustom) {
                Text(showCustom && !customURL.isEmpty ? "Use this server" : "Continue")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(showCustom && AppState.normalizedServerURL(customURL) == nil)
            .accessibilityIdentifier("onboarding.server.continue")
        }
        .onAppear {
            customURL = ""
            if app.didCompleteServerSetup { onContinue() }
        }
    }

    private func select(_ url: String) {
        if app.saveServerURL(url) {
            inlineError = nil
            onContinue()
        } else {
            inlineError = app.lastError
            app.clearError()
        }
    }

    private func submitCustom() {
        if showCustom && !customURL.isEmpty {
            select(customURL)
        } else {
            select(app.serverURLString)
        }
    }

    private struct Preset: Identifiable {
        let id = UUID()
        let name: LocalizedStringResource
        let subtitle: LocalizedStringResource
        let url: String
        let systemImage: String
    }

    private struct PresetRow: View {
        let preset: Preset
        let isSelected: Bool

        var body: some View {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(MulticaTheme.brand.opacity(0.12))
                    Image(systemName: preset.systemImage).foregroundStyle(MulticaTheme.brand)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name).font(.body.weight(.semibold))
                    Text(preset.subtitle).font(.caption).foregroundStyle(.secondary)
                    Text(preset.url).font(.caption2.monospaced()).foregroundStyle(.tertiary).lineLimit(1)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").foregroundStyle(MulticaTheme.brand).fontWeight(.semibold)
                }
                Image(systemName: "chevron.right").foregroundStyle(.tertiary).font(.subheadline)
            }
            .cardSurface(padding: 14)
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Step 2: Sign-in method

enum SignInMethod {
    case email, token
}

private struct SignInMethodStep: View {
    @Environment(AppState.self) private var app
    let onSelect: (SignInMethod) -> Void

    var body: some View {
        OnboardingScreen(step: 2, total: 4) {
            OnboardingHero(systemImage: "key.fill", title: "Sign in", subtitle: "Pick how you want to sign in to \(serverHost).")
            VStack(spacing: 12) {
                MethodRow(
                    systemImage: "envelope.fill",
                    title: "Email code",
                    subtitle: "We'll email you a one-time code.",
                    recommended: true
                ) { onSelect(.email) }
                .accessibilityIdentifier("onboarding.method.email")

                MethodRow(
                    systemImage: "key.horizontal",
                    title: "Existing API token",
                    subtitle: "Paste a Personal Access Token from your settings.",
                    recommended: false
                ) { onSelect(.token) }
                .accessibilityIdentifier("onboarding.method.token")
            }
        } footer: {
            Button(role: .none) { app.resetServerSetup() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("Change server")
                }
                .font(.callout)
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(.secondary)
        }
    }

    private var serverHost: String {
        URL(string: app.serverURLString)?.host ?? app.serverURLString
    }

    private struct MethodRow: View {
        let systemImage: String
        let title: LocalizedStringResource
        let subtitle: LocalizedStringResource
        let recommended: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(MulticaTheme.brand.opacity(0.12))
                        Image(systemName: systemImage).foregroundStyle(MulticaTheme.brand)
                    }
                    .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(title).font(.body.weight(.semibold))
                            if recommended {
                                Text("Recommended")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .foregroundStyle(MulticaTheme.brand)
                                    .background(MulticaTheme.brand.opacity(0.14), in: Capsule())
                            }
                        }
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary).font(.subheadline)
                }
                .cardSurface(padding: 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Step 3a: Email entry

private struct EmailEntryStep: View {
    @Environment(AppState.self) private var app
    let onSent: (String) -> Void

    @State private var email = ""
    @State private var sending = false
    @State private var inlineError: String?
    @FocusState private var focused: Bool

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isValid: Bool {
        let parts = trimmedEmail.split(separator: "@")
        return parts.count == 2 && parts[0].count >= 1 && parts[1].contains(".")
    }

    var body: some View {
        OnboardingScreen(step: 3, total: 4) {
            OnboardingHero(systemImage: "envelope.open.fill", title: "What's your email?", subtitle: "We'll send a 6-digit code to sign you in.")
            VStack(alignment: .leading, spacing: 10) {
                TextField("you@example.com", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .focused($focused)
                    .onSubmit(send)
                    .accessibilityIdentifier("onboarding.email.field")
                if let inlineError {
                    InlineError(message: inlineError)
                }
            }
            .cardSurface()
        } footer: {
            Button(action: send) {
                Text(sending ? "Sending…" : "Send code")
            }
            .buttonStyle(PrimaryButtonStyle(isLoading: sending))
            .disabled(!isValid || sending)
            .accessibilityIdentifier("onboarding.email.send")
        }
        .onAppear { focused = true }
    }

    private func send() {
        guard isValid, !sending else { return }
        sending = true
        inlineError = nil
        Task {
            let ok = await app.sendCode(email: trimmedEmail)
            sending = false
            if ok {
                onSent(trimmedEmail)
            } else {
                inlineError = app.lastError ?? "Could not send code. Check the email and try again."
                app.clearError()
            }
        }
    }
}

// MARK: - Step 3b: Verify code

private struct VerifyCodeStep: View {
    @Environment(AppState.self) private var app
    let email: String

    @State private var code = ""
    @State private var verifying = false
    @State private var inlineError: String?
    @State private var resending = false
    @FocusState private var focused: Bool

    private var trimmedCode: String { code.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSubmit: Bool { trimmedCode.count >= 4 }

    var body: some View {
        OnboardingScreen(step: 4, total: 4) {
            OnboardingHero(systemImage: "lock.shield.fill", title: "Enter the code", subtitle: "We sent a code to \(email).")
            VStack(alignment: .leading, spacing: 12) {
                TextField("123456", text: $code)
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
                    .font(.title2.monospacedDigit())
                    .multilineTextAlignment(.center)
                    .focused($focused)
                    .submitLabel(.go)
                    .accessibilityIdentifier("onboarding.code.field")
                    .onSubmit(verify)
                    .onChange(of: code) { _, newValue in
                        let digits = newValue.filter(\.isNumber).prefix(6)
                        if digits != Substring(newValue) { code = String(digits) }
                        if digits.count == 6 { verify() }
                    }
                if let inlineError {
                    InlineError(message: inlineError)
                }
                HStack {
                    Button {
                        Task { await resend() }
                    } label: {
                        Text(resending ? "Sending…" : "Resend code")
                            .font(.callout)
                    }
                    .disabled(resending)
                    Spacer()
                }
            }
            .cardSurface()
        } footer: {
            Button(action: verify) {
                Text(verifying ? "Verifying…" : "Verify and sign in")
            }
            .buttonStyle(PrimaryButtonStyle(isLoading: verifying))
            .disabled(!canSubmit || verifying)
            .accessibilityIdentifier("onboarding.code.verify")
        }
        .onAppear { focused = true }
    }

    private func verify() {
        guard canSubmit, !verifying else { return }
        verifying = true
        inlineError = nil
        Task {
            let ok = await app.verifyCode(email: email, code: trimmedCode)
            verifying = false
            if !ok {
                inlineError = app.lastError ?? "That code didn't work. Try again."
                app.clearError()
            }
        }
    }

    private func resend() async {
        resending = true
        _ = await app.sendCode(email: email)
        resending = false
    }
}

// MARK: - Step 3c: Token entry

private struct TokenEntryStep: View {
    @Environment(AppState.self) private var app

    @State private var token = ""
    @State private var signingIn = false
    @State private var inlineError: String?
    @FocusState private var focused: Bool

    private var trimmed: String { token.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        OnboardingScreen(step: 3, total: 4) {
            OnboardingHero(systemImage: "key.horizontal.fill", title: "Paste your token", subtitle: "Use a Personal Access Token from your Multica server.")
            VStack(alignment: .leading, spacing: 10) {
                SecureField("Paste token here", text: $token)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .submitLabel(.go)
                    .onSubmit(signIn)
                    .accessibilityIdentifier("onboarding.token.field")
                if let inlineError {
                    InlineError(message: inlineError)
                } else {
                    Text("Tokens are stored in Keychain and scoped to the current server.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .cardSurface()
        } footer: {
            Button(action: signIn) {
                Text(signingIn ? "Signing in…" : "Sign in")
            }
            .buttonStyle(PrimaryButtonStyle(isLoading: signingIn))
            .disabled(trimmed.isEmpty || signingIn)
            .accessibilityIdentifier("onboarding.token.signin")
        }
        .onAppear { focused = true }
    }

    private func signIn() {
        guard !trimmed.isEmpty, !signingIn else { return }
        signingIn = true
        inlineError = nil
        Task {
            let ok = await app.useManualToken(trimmed)
            signingIn = false
            if !ok {
                inlineError = app.lastError ?? "That token didn't work."
                app.clearError()
            }
        }
    }
}

// MARK: - Shared chrome

private struct OnboardingScreen<Body: View, Footer: View>: View {
    let step: Int
    let total: Int
    var hideBack: Bool = false
    @ViewBuilder let content: () -> Body
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    content()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 12) {
                StepIndicator(current: step, total: total)
                footer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .padding(.top, 12)
            .background(.background)
        }
        .background(.background)
        .toolbar(hideBack ? .hidden : .visible, for: .navigationBar)
    }
}
