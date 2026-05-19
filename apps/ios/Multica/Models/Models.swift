import Foundation

struct User: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let email: String
    let avatarUrl: String?
    let createdAt: String?
    let updatedAt: String?
}

struct Workspace: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let issuePrefix: String?
    let avatarUrl: String?
    let createdAt: String?
    let updatedAt: String?
}

struct Issue: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let workspaceId: String?
    let number: Int?
    let identifier: String?
    var title: String
    var description: String?
    var status: String
    var priority: String
    let assigneeType: String?
    let assigneeId: String?
    let creatorType: String?
    let creatorId: String?
    let parentIssueId: String?
    let projectId: String?
    let startDate: String?
    let dueDate: String?
    let labels: [IssueLabel]?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, workspaceId, number, identifier, title, description, status, priority, assigneeType, assigneeId, creatorType, creatorId, parentIssueId, projectId, startDate, dueDate, labels, createdAt, updatedAt
    }

    init(
        id: String,
        workspaceId: String? = nil,
        number: Int? = nil,
        identifier: String? = nil,
        title: String,
        description: String? = nil,
        status: String = "todo",
        priority: String = "none",
        assigneeType: String? = nil,
        assigneeId: String? = nil,
        creatorType: String? = nil,
        creatorId: String? = nil,
        parentIssueId: String? = nil,
        projectId: String? = nil,
        startDate: String? = nil,
        dueDate: String? = nil,
        labels: [IssueLabel]? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.number = number
        self.identifier = identifier
        self.title = title
        self.description = description
        self.status = status
        self.priority = priority
        self.assigneeType = assigneeType
        self.assigneeId = assigneeId
        self.creatorType = creatorType
        self.creatorId = creatorId
        self.parentIssueId = parentIssueId
        self.projectId = projectId
        self.startDate = startDate
        self.dueDate = dueDate
        self.labels = labels
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        workspaceId = try container.decodeIfPresent(String.self, forKey: .workspaceId)
        number = try container.decodeIfPresent(Int.self, forKey: .number)
        identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
        title = try container.decodeIfPresent(String.self, forKey: .title)?.nilIfBlank ?? "Untitled issue"
        description = try container.decodeIfPresent(String.self, forKey: .description)
        status = try container.decodeIfPresent(String.self, forKey: .status)?.nilIfBlank ?? "todo"
        priority = try container.decodeIfPresent(String.self, forKey: .priority)?.nilIfBlank ?? "none"
        assigneeType = try container.decodeIfPresent(String.self, forKey: .assigneeType)
        assigneeId = try container.decodeIfPresent(String.self, forKey: .assigneeId)
        creatorType = try container.decodeIfPresent(String.self, forKey: .creatorType)
        creatorId = try container.decodeIfPresent(String.self, forKey: .creatorId)
        parentIssueId = try container.decodeIfPresent(String.self, forKey: .parentIssueId)
        projectId = try container.decodeIfPresent(String.self, forKey: .projectId)
        startDate = try container.decodeIfPresent(String.self, forKey: .startDate)
        dueDate = try container.decodeIfPresent(String.self, forKey: .dueDate)
        if let decodedLabels = try? container.decode([FailableDecodable<IssueLabel>].self, forKey: .labels) {
            labels = decodedLabels.compactMap(\.value)
        } else {
            labels = nil
        }
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

struct IssueLabel: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let color: String?
}

struct Comment: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let issueId: String?
    let authorType: String?
    let authorId: String?
    let content: String
    let type: String?
    let parentId: String?
    let createdAt: String?
    let updatedAt: String?
}

struct InboxItem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let workspaceId: String?
    let type: String
    let severity: String?
    let issueId: String?
    let title: String
    let body: String?
    let issueStatus: String?
    var read: Bool
    var archived: Bool
    let createdAt: String?
}

struct Agent: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let workspaceId: String?
    let runtimeId: String?
    let name: String
    let description: String?
    let avatarUrl: String?
    let runtimeMode: String?
    let visibility: String?
    let status: String?
    let model: String?
    let ownerId: String?
    let createdAt: String?
    let updatedAt: String?
    let archivedAt: String?
}

struct Project: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let workspaceId: String?
    var title: String
    var description: String?
    var icon: String?
    var status: String?
    var priority: String?
    var leadType: String?
    var leadId: String?
    let issueCount: Int?
    let doneCount: Int?
    let resourceCount: Int?
    let createdAt: String?
    let updatedAt: String?
}

struct ProjectResource: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let projectId: String?
    let workspaceId: String?
    let resourceType: String
    let resourceRef: ResourceRef?
    let label: String?
    let position: Int?
    let createdAt: String?
    let createdBy: String?
}

struct ResourceRef: Codable, Hashable, Sendable {
    let url: String?
    let defaultBranchHint: String?
}

struct Squad: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let workspaceId: String?
    var name: String
    var description: String?
    var instructions: String?
    let avatarUrl: String?
    var leaderId: String?
    let creatorId: String?
    let createdAt: String?
    let updatedAt: String?
    let archivedAt: String?
    let archivedBy: String?
}

struct SquadMember: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let squadId: String?
    let memberType: String
    let memberId: String
    var role: String?
    let createdAt: String?
}

struct Autopilot: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let workspaceId: String?
    var title: String
    var description: String?
    let assigneeId: String
    var status: String
    var executionMode: String
    var issueTitleTemplate: String?
    let createdByType: String?
    let createdById: String?
    let lastRunAt: String?
    let createdAt: String?
    let updatedAt: String?
}

struct AutopilotTrigger: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let autopilotId: String?
    let kind: String
    let enabled: Bool
    let cronExpression: String?
    let timezone: String?
    let nextRunAt: String?
    let label: String?
    let lastFiredAt: String?
    let createdAt: String?
    let updatedAt: String?
}

struct AutopilotRun: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let autopilotId: String?
    let triggerId: String?
    let source: String
    let status: String
    let issueId: String?
    let taskId: String?
    let triggeredAt: String?
    let completedAt: String?
    let failureReason: String?
    let createdAt: String?
}

struct ListAutopilotsResponse: Codable, Sendable {
    let autopilots: [Autopilot]
    let total: Int?
}

struct GetAutopilotResponse: Codable, Sendable {
    let autopilot: Autopilot
    let triggers: [AutopilotTrigger]
}

struct ListAutopilotRunsResponse: Codable, Sendable {
    let runs: [AutopilotRun]
    let total: Int?
}

struct UpdateAutopilotPayload: Codable, Sendable {
    let title: String?
    let description: String?
    let assigneeId: String?
    let status: String?
    let executionMode: String?
    let issueTitleTemplate: String?
}

struct ListIssuesResponse: Codable, Sendable {
    let issues: [Issue]
    let total: Int?

    enum CodingKeys: String, CodingKey { case issues, total }

    init(issues: [Issue], total: Int?) {
        self.issues = issues
        self.total = total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decoded = (try? container.decode([FailableDecodable<Issue>].self, forKey: .issues)) ?? []
        issues = decoded.compactMap(\.value)
        total = try container.decodeIfPresent(Int.self, forKey: .total)
    }
}

struct ListProjectsResponse: Codable, Sendable {
    let projects: [Project]
    let total: Int?
}

struct ListProjectResourcesResponse: Codable, Sendable {
    let resources: [ProjectResource]
    let total: Int?
}

struct LoginResponse: Codable, Sendable {
    let token: String
    let user: User
}

struct CountResponse: Codable, Sendable {
    let count: Int
}

struct CreateIssuePayload: Codable, Sendable {
    let workspaceId: String
    let title: String
    let description: String?
    let status: String
    let priority: String
    let assigneeType: String?
    let assigneeId: String?
}

struct UpdateIssuePayload: Codable, Sendable {
    let title: String?
    let description: String?
    let status: String?
    let priority: String?
    let assigneeType: String?
    let assigneeId: String?
}

struct CreateProjectPayload: Codable, Sendable {
    let title: String
    let description: String?
    let icon: String?
    let status: String
    let priority: String
    let leadType: String?
    let leadId: String?
}

struct UpdateProjectPayload: Codable, Sendable {
    let title: String?
    let description: String?
    let icon: String?
    let status: String?
    let priority: String?
    let leadType: String?
    let leadId: String?
}

struct CreateCommentPayload: Codable, Sendable {
    let content: String
    let type: String
}

struct SendCodePayload: Codable, Sendable { let email: String }
struct VerifyCodePayload: Codable, Sendable { let email: String; let code: String }

private struct FailableDecodable<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
