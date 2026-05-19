import XCTest
@testable import Multica

final class KeychainStoreTests: XCTestCase {
    func testKeychainStorePersistsTokenForAccount() throws {
        let service = "ai.multica.mobile.tests.\(UUID().uuidString)"
        let store = KeychainStore(service: service)
        let account = "token@https://agents.l.voska.org"
        defer { store.delete(account: account) }

        do {
            try store.save("secret-token", account: account)
            XCTAssertEqual(try store.read(account: account), "secret-token")
        } catch let error as KeychainError where error.status == errSecMissingEntitlement {
            throw XCTSkip("Keychain requires a signed simulator build; unsigned CODE_SIGNING_ALLOWED=NO builds cannot persist tokens.")
        }
    }
}
