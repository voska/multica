import XCTest
@testable import Multica

final class APIClientTests: XCTestCase {
    func testAuthEndpointsDoNotSendAuthorizationHeader() async throws {
        let session = MockAPISession(data: Data(), statusCode: 204)
        let client = APIClient(baseURL: URL(string: "https://agents.l.voska.org")!, token: "secret-token", session: session)

        try await client.sendCode(email: "matt@example.com")

        XCTAssertNil(session.lastRequest?.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(session.lastRequest?.url?.path, "/auth/send-code")
    }

    func testAuthenticatedRequestsSendClientAndWorkspaceHeaders() async throws {
        let body = #"{"id":"u1","name":"Matt","email":"matt@example.com","avatar_url":null,"created_at":"now","updated_at":"now"}"#.data(using: .utf8)!
        let session = MockAPISession(data: body, statusCode: 200)
        let client = APIClient(baseURL: URL(string: "https://agents.l.voska.org")!, token: "secret-token", workspaceID: "ws-1", session: session)

        _ = try await client.getMe()

        XCTAssertEqual(session.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")
        XCTAssertEqual(session.lastRequest?.value(forHTTPHeaderField: "X-Workspace-ID"), "ws-1")
        XCTAssertEqual(session.lastRequest?.value(forHTTPHeaderField: "X-Client-Platform"), "ios")
        XCTAssertNotNil(session.lastRequest?.value(forHTTPHeaderField: "X-Request-ID"))
    }

    func testCreateIssueEncodesSnakeCasePayload() async throws {
        let response = #"{"id":"i1","workspace_id":"ws-1","number":1,"identifier":"T-1","title":"Fix it","description":null,"status":"todo","priority":"medium","assignee_type":null,"assignee_id":null,"creator_type":"member","creator_id":"u1","parent_issue_id":null,"project_id":null,"start_date":null,"due_date":null,"created_at":"now","updated_at":"now"}"#.data(using: .utf8)!
        let session = MockAPISession(data: response, statusCode: 200)
        let client = APIClient(baseURL: URL(string: "https://agents.l.voska.org")!, token: "secret-token", session: session)
        let payload = CreateIssuePayload(workspaceId: "ws-1", title: "Fix it", description: nil, status: "todo", priority: "medium", assigneeType: "agent", assigneeId: "a1")

        _ = try await client.createIssue(payload)

        let body = try XCTUnwrap(session.lastRequest?.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(json?["workspace_id"] as? String, "ws-1")
        XCTAssertEqual(json?["assignee_type"] as? String, "agent")
        XCTAssertNil(json?["workspaceId"])
    }

    func testSquadAndProjectDetailEndpointsUseExpectedPaths() async throws {
        let squad = #"{"id":"s1","workspace_id":"ws-1","name":"Finance","description":"","instructions":"route work","avatar_url":null,"leader_id":"a1","creator_id":"u1","created_at":"now","updated_at":"now","archived_at":null,"archived_by":null}"#.data(using: .utf8)!
        let session = MockAPISession(data: squad, statusCode: 200)
        let client = APIClient(baseURL: URL(string: "https://agents.l.voska.org")!, token: "secret-token", workspaceID: "ws-1", session: session)

        _ = try await client.getSquad("s1")

        XCTAssertEqual(session.lastRequest?.url?.path, "/api/squads/s1")
        XCTAssertEqual(session.lastRequest?.value(forHTTPHeaderField: "X-Workspace-ID"), "ws-1")

        let project = #"{"id":"p1","workspace_id":"ws-1","title":"Launch","description":null,"icon":null,"status":"planned","priority":"medium","lead_type":null,"lead_id":null,"issue_count":0,"done_count":0,"resource_count":0,"created_at":"now","updated_at":"now"}"#.data(using: .utf8)!
        session.data = project
        _ = try await client.getProject("p1")

        XCTAssertEqual(session.lastRequest?.url?.path, "/api/projects/p1")
    }

    func testHTTP401ThrowsUnauthorizedError() async throws {
        let error = #"{"error":"invalid token"}"#.data(using: .utf8)!
        let session = MockAPISession(data: error, statusCode: 401)
        let client = APIClient(baseURL: URL(string: "https://agents.l.voska.org")!, token: "bad", session: session)

        do {
            _ = try await client.getMe()
            XCTFail("Expected 401")
        } catch APIClient.APIError.unauthorized(let message) {
            XCTAssertEqual(message, "invalid token")
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}

final class MockAPISession: APIClientSession, @unchecked Sendable {
    var data: Data
    var statusCode: Int
    private(set) var lastRequest: URLRequest?

    init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (data, response)
    }
}
