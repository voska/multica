import XCTest
@testable import Multica

@MainActor
final class AppStateTests: XCTestCase {
    func testServerSetupPersistsCompletionWithoutRequiringToken() {
        let defaults = UserDefaults(suiteName: "AppStateTests-\(UUID().uuidString)")!
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }
        let tokenStore = MemoryTokenStore()
        let app = AppState(defaults: defaults, tokenStore: tokenStore)

        XCTAssertFalse(app.didCompleteServerSetup)
        XCTAssertNil(app.token)

        XCTAssertTrue(app.saveServerURL("agents.l.voska.org"))

        XCTAssertTrue(app.didCompleteServerSetup)
        XCTAssertNil(app.token)
        XCTAssertEqual(app.serverURLString, "https://agents.l.voska.org")
    }

    func testServerURLNormalizationRequiresHTTPSAndValidHost() {
        XCTAssertEqual(AppState.normalizedServerURL("agents.l.voska.org"), "https://agents.l.voska.org")
        XCTAssertEqual(AppState.normalizedServerURL(" https://agents.l.voska.org/ "), "https://agents.l.voska.org")
        XCTAssertNil(AppState.normalizedServerURL("http://agents.l.voska.org"))
        XCTAssertNil(AppState.normalizedServerURL("https://"))
        XCTAssertNil(AppState.normalizedServerURL("not a host"))
    }

    func testTokenAccountIsScopedByServerOrigin() {
        XCTAssertEqual(AppState.tokenAccountName(for: "https://agents.l.voska.org"), "token@https://agents.l.voska.org")
        XCTAssertEqual(AppState.tokenAccountName(for: "https://app.multica.ai"), "token@https://app.multica.ai")
        XCTAssertEqual(AppState.tokenAccountName(for: "https://localhost:8080"), "token@https://localhost:8080")
    }

    func testChangingServerClearsExistingToken() {
        let defaults = UserDefaults(suiteName: "AppStateTests-\(UUID().uuidString)")!
        let tokenStore = MemoryTokenStore()
        let app = AppState(defaults: defaults, tokenStore: tokenStore)
        XCTAssertTrue(app.saveServerURL("https://app.multica.ai"))
        app.setTokenForTesting("secret-token")
        XCTAssertEqual(app.token, "secret-token")

        XCTAssertTrue(app.saveServerURL("https://agents.l.voska.org"))

        XCTAssertNil(app.token)
        XCTAssertNil(try? tokenStore.read(account: "token@https://app.multica.ai"))
    }

    func testManualTokenValidationRejectsWhitespace() {
        XCTAssertNil(AppState.validatedManualToken("   \n"))
        XCTAssertEqual(AppState.validatedManualToken("  abc.def.ghi  "), "abc.def.ghi")
    }

    func testWorkspaceSelectionPersistsSelectedWorkspaceID() async {
        let defaults = UserDefaults(suiteName: "AppStateTests-\(UUID().uuidString)")!
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }
        let app = AppState(defaults: defaults, tokenStore: MemoryTokenStore())
        let workspace = Workspace(
            id: "ws-2",
            name: "SensAI",
            slug: "sensai",
            description: nil,
            issuePrefix: "SEN",
            avatarUrl: nil,
            createdAt: nil,
            updatedAt: nil
        )

        await app.selectWorkspace(workspace, refresh: false)

        XCTAssertEqual(app.selectedWorkspace?.id, "ws-2")
        XCTAssertEqual(defaults.string(forKey: "selectedWorkspaceID"), "ws-2")
    }

    private func defaultsSuiteName(_ defaults: UserDefaults) -> String {
        defaults.volatileDomainNames.first(where: { $0.hasPrefix("AppStateTests-") }) ?? ""
    }
}

final class MemoryTokenStore: TokenStoring {
    private var storage: [String: String] = [:]

    func save(_ value: String, account: String) throws { storage[account] = value }
    func read(account: String) throws -> String? { storage[account] }
    func delete(account: String) { storage.removeValue(forKey: account) }
}
