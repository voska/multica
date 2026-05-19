import XCTest
@testable import Multica

final class APIShapeTests: XCTestCase {
    func testIssueDecodesSnakeCasePayload() throws {
        let json = #"""
        {
          "id": "abc",
          "workspace_id": "ws",
          "number": 42,
          "identifier": "MUL-42",
          "title": "Ship iOS app",
          "description": null,
          "status": "in_progress",
          "priority": "high",
          "assignee_type": "agent",
          "assignee_id": "agent-1",
          "creator_type": "member",
          "creator_id": "user-1",
          "parent_issue_id": null,
          "project_id": null,
          "start_date": null,
          "due_date": null,
          "created_at": "2026-05-17T00:00:00Z",
          "updated_at": "2026-05-17T00:00:00Z"
        }
        """#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let issue = try decoder.decode(Issue.self, from: json)
        XCTAssertEqual(issue.identifier, "MUL-42")
        XCTAssertEqual(issue.status, "in_progress")
    }

    func testIssueDecodingFallsBackForDriftingNullableFieldsAndMalformedLabels() throws {
        let json = #"""
        {
          "id": "abc",
          "workspace_id": "ws",
          "number": 42,
          "identifier": null,
          "title": null,
          "description": null,
          "status": null,
          "priority": null,
          "assignee_type": null,
          "assignee_id": null,
          "creator_type": null,
          "creator_id": null,
          "parent_issue_id": null,
          "project_id": null,
          "start_date": null,
          "due_date": null,
          "labels": [{"label_id":"legacy-ref"}, {"id":"l1","name":"Bug","color":"red"}],
          "created_at": "2026-05-17T00:00:00Z",
          "updated_at": "2026-05-17T00:00:00Z"
        }
        """#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let issue = try decoder.decode(Issue.self, from: json)
        XCTAssertEqual(issue.title, "Untitled issue")
        XCTAssertEqual(issue.status, "todo")
        XCTAssertEqual(issue.priority, "none")
        XCTAssertEqual(issue.labels, [IssueLabel(id: "l1", name: "Bug", color: "red")])
    }

    func testWorkspaceDecodesSelfHostedPayload() throws {
        let json = #"""
        {"id":"ws","name":"Voska","slug":"voska","description":null,"context":null,"settings":{},"repos":[],"issue_prefix":"VOS","avatar_url":null,"created_at":"now","updated_at":"now"}
        """#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let workspace = try decoder.decode(Workspace.self, from: json)
        XCTAssertEqual(workspace.issuePrefix, "VOS")
    }
}
