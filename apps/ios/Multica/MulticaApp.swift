import SwiftUI

@main
struct MulticaApp: App {
    @State private var appState: AppState

    init() {
        let state = AppState()
        #if DEBUG
        if ProcessInfo.processInfo.environment["MULTICA_MOCK"] == "1" {
            state.seedMockForPreview()
        }
        #endif
        _appState = State(initialValue: state)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(nil)
        }
    }
}
