// Generated from packages/core/types — do not edit by hand.
// Run `pnpm --filter @multica/ios codegen` to regenerate.

import Foundation

enum Generated {}

extension Generated {
    /// Mirrors `User` from packages/core/types.
    /// Generated — do not edit by hand. Run `pnpm --filter @multica/ios codegen`.
    struct User: Codable, Identifiable, Hashable, Sendable {
        let id: String
        let name: String
        let email: String
        let avatarUrl: String?
        let onboardedAt: String?
        let onboardingQuestionnaire: AnyCodable
        let starterContentState: String?
        let language: String?
        let profileDescription: String
        let createdAt: String
        let updatedAt: String
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case email
            case avatarUrl = "avatar_url"
            case onboardedAt = "onboarded_at"
            case onboardingQuestionnaire = "onboarding_questionnaire"
            case starterContentState = "starter_content_state"
            case language
            case profileDescription = "profile_description"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    /// Mirrors `Workspace` from packages/core/types.
    /// Generated — do not edit by hand. Run `pnpm --filter @multica/ios codegen`.
    struct Workspace: Codable, Identifiable, Hashable, Sendable {
        let id: String
        let name: String
        let slug: String
        let description: String?
        let context: String?
        let settings: AnyCodable
        let repos: [AnyCodable]
        let issuePrefix: String
        let createdAt: String
        let updatedAt: String
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case slug
            case description
            case context
            case settings
            case repos
            case issuePrefix = "issue_prefix"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    /// Mirrors `Issue` from packages/core/types.
    /// Generated — do not edit by hand. Run `pnpm --filter @multica/ios codegen`.
    struct Issue: Codable, Identifiable, Hashable, Sendable {
        let id: String
        let workspaceId: String
        let number: Double
        let identifier: String
        let title: String
        let description: String?
        let status: AnyCodable
        let priority: AnyCodable
        let assigneeType: AnyCodable?
        let assigneeId: String?
        let creatorType: AnyCodable
        let creatorId: String
        let parentIssueId: String?
        let projectId: String?
        let position: Double
        let startDate: String?
        let dueDate: String?
        let reactions: [AnyCodable]?
        let labels: [Label]?
        let createdAt: String
        let updatedAt: String
        enum CodingKeys: String, CodingKey {
            case id
            case workspaceId = "workspace_id"
            case number
            case identifier
            case title
            case description
            case status
            case priority
            case assigneeType = "assignee_type"
            case assigneeId = "assignee_id"
            case creatorType = "creator_type"
            case creatorId = "creator_id"
            case parentIssueId = "parent_issue_id"
            case projectId = "project_id"
            case position
            case startDate = "start_date"
            case dueDate = "due_date"
            case reactions
            case labels
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    /// Mirrors `Label` from packages/core/types.
    /// Generated — do not edit by hand. Run `pnpm --filter @multica/ios codegen`.
    struct Label: Codable, Identifiable, Hashable, Sendable {
        let id: String
        let workspaceId: String
        let name: String
        let color: String
        let createdAt: String
        let updatedAt: String
        enum CodingKeys: String, CodingKey {
            case id
            case workspaceId = "workspace_id"
            case name
            case color
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    /// Mirrors `Comment` from packages/core/types.
    /// Generated — do not edit by hand. Run `pnpm --filter @multica/ios codegen`.
    struct Comment: Codable, Identifiable, Hashable, Sendable {
        let id: String
        let issueId: String
        let authorType: AnyCodable
        let authorId: String
        let content: String
        let type: AnyCodable
        let parentId: String?
        let reactions: [AnyCodable]
        let attachments: [AnyCodable]
        let createdAt: String
        let updatedAt: String
        let resolvedAt: String?
        let resolvedByType: AnyCodable?
        let resolvedById: String?
        enum CodingKeys: String, CodingKey {
            case id
            case issueId = "issue_id"
            case authorType = "author_type"
            case authorId = "author_id"
            case content
            case type
            case parentId = "parent_id"
            case reactions
            case attachments
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case resolvedAt = "resolved_at"
            case resolvedByType = "resolved_by_type"
            case resolvedById = "resolved_by_id"
        }
    }

    /// Mirrors `InboxItem` from packages/core/types.
    /// Generated — do not edit by hand. Run `pnpm --filter @multica/ios codegen`.
    struct InboxItem: Codable, Identifiable, Hashable, Sendable {
        let id: String
        let workspaceId: String
        let recipientType: String
        let recipientId: String
        let actorType: String?
        let actorId: String?
        let type: AnyCodable
        let severity: AnyCodable
        let issueId: String?
        let title: String
        let body: String?
        let issueStatus: AnyCodable?
        let read: Bool
        let archived: Bool
        let createdAt: String
        let details: AnyCodable?
        enum CodingKeys: String, CodingKey {
            case id
            case workspaceId = "workspace_id"
            case recipientType = "recipient_type"
            case recipientId = "recipient_id"
            case actorType = "actor_type"
            case actorId = "actor_id"
            case type
            case severity
            case issueId = "issue_id"
            case title
            case body
            case issueStatus = "issue_status"
            case read
            case archived
            case createdAt = "created_at"
            case details
        }
    }

    /// Mirrors `Agent` from packages/core/types.
    /// Generated — do not edit by hand. Run `pnpm --filter @multica/ios codegen`.
    struct Agent: Codable, Identifiable, Hashable, Sendable {
        let id: String
        let workspaceId: String
        let runtimeId: String
        let name: String
        let description: String
        let instructions: String
        let avatarUrl: String?
        let runtimeMode: AnyCodable
        let runtimeConfig: AnyCodable
        let customEnv: AnyCodable
        let customArgs: [String]
        let customEnvRedacted: Bool
        let visibility: AnyCodable
        let status: AnyCodable
        let maxConcurrentTasks: Double
        let model: String
        let ownerId: String?
        let skills: [AnyCodable]
        let createdAt: String
        let updatedAt: String
        let archivedAt: String?
        let archivedBy: String?
        enum CodingKeys: String, CodingKey {
            case id
            case workspaceId = "workspace_id"
            case runtimeId = "runtime_id"
            case name
            case description
            case instructions
            case avatarUrl = "avatar_url"
            case runtimeMode = "runtime_mode"
            case runtimeConfig = "runtime_config"
            case customEnv = "custom_env"
            case customArgs = "custom_args"
            case customEnvRedacted = "custom_env_redacted"
            case visibility
            case status
            case maxConcurrentTasks = "max_concurrent_tasks"
            case model
            case ownerId = "owner_id"
            case skills
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case archivedAt = "archived_at"
            case archivedBy = "archived_by"
        }
    }

    /// Mirrors `Project` from packages/core/types.
    /// Generated — do not edit by hand. Run `pnpm --filter @multica/ios codegen`.
    struct Project: Codable, Identifiable, Hashable, Sendable {
        let id: String
        let workspaceId: String
        let title: String
        let description: String?
        let icon: String?
        let status: AnyCodable
        let priority: AnyCodable
        let leadType: String?
        let leadId: String?
        let createdAt: String
        let updatedAt: String
        let issueCount: Double
        let doneCount: Double
        let resourceCount: Double
        enum CodingKeys: String, CodingKey {
            case id
            case workspaceId = "workspace_id"
            case title
            case description
            case icon
            case status
            case priority
            case leadType = "lead_type"
            case leadId = "lead_id"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case issueCount = "issue_count"
            case doneCount = "done_count"
            case resourceCount = "resource_count"
        }
    }

    /// Mirrors `ProjectResource` from packages/core/types.
    /// Generated — do not edit by hand. Run `pnpm --filter @multica/ios codegen`.
    struct ProjectResource: Codable, Identifiable, Hashable, Sendable {
        let id: String
        let projectId: String
        let workspaceId: String
        let resourceType: AnyCodable
        let resourceRef: AnyCodable
        let label: String?
        let position: Double
        let createdAt: String
        let createdBy: String?
        enum CodingKeys: String, CodingKey {
            case id
            case projectId = "project_id"
            case workspaceId = "workspace_id"
            case resourceType = "resource_type"
            case resourceRef = "resource_ref"
            case label
            case position
            case createdAt = "created_at"
            case createdBy = "created_by"
        }
    }

    /// Mirrors `Squad` from packages/core/types.
    /// Generated — do not edit by hand. Run `pnpm --filter @multica/ios codegen`.
    struct Squad: Codable, Identifiable, Hashable, Sendable {
        let id: String
        let workspaceId: String
        let name: String
        let description: String
        let instructions: String
        let avatarUrl: String?
        let leaderId: String
        let creatorId: String
        let createdAt: String
        let updatedAt: String
        let archivedAt: String?
        let archivedBy: String?
        enum CodingKeys: String, CodingKey {
            case id
            case workspaceId = "workspace_id"
            case name
            case description
            case instructions
            case avatarUrl = "avatar_url"
            case leaderId = "leader_id"
            case creatorId = "creator_id"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case archivedAt = "archived_at"
            case archivedBy = "archived_by"
        }
    }

    /// Mirrors `SquadMember` from packages/core/types.
    /// Generated — do not edit by hand. Run `pnpm --filter @multica/ios codegen`.
    struct SquadMember: Codable, Identifiable, Hashable, Sendable {
        let id: String
        let squadId: String
        let memberType: AnyCodable
        let memberId: String
        let role: String
        let createdAt: String
        enum CodingKeys: String, CodingKey {
            case id
            case squadId = "squad_id"
            case memberType = "member_type"
            case memberId = "member_id"
            case role
            case createdAt = "created_at"
        }
    }

    /// Mirrors `Autopilot` from packages/core/types.
    /// Generated — do not edit by hand. Run `pnpm --filter @multica/ios codegen`.
    struct Autopilot: Codable, Identifiable, Hashable, Sendable {
        let id: String
        let workspaceId: String
        let title: String
        let description: String?
        let assigneeId: String
        let status: AnyCodable
        let executionMode: AnyCodable
        let issueTitleTemplate: String?
        let createdByType: String
        let createdById: String
        let lastRunAt: String?
        let createdAt: String
        let updatedAt: String
        enum CodingKeys: String, CodingKey {
            case id
            case workspaceId = "workspace_id"
            case title
            case description
            case assigneeId = "assignee_id"
            case status
            case executionMode = "execution_mode"
            case issueTitleTemplate = "issue_title_template"
            case createdByType = "created_by_type"
            case createdById = "created_by_id"
            case lastRunAt = "last_run_at"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    /// Mirrors `AutopilotTrigger` from packages/core/types.
    /// Generated — do not edit by hand. Run `pnpm --filter @multica/ios codegen`.
    struct AutopilotTrigger: Codable, Identifiable, Hashable, Sendable {
        let id: String
        let autopilotId: String
        let kind: AnyCodable
        let enabled: Bool
        let cronExpression: String?
        let timezone: String?
        let nextRunAt: String?
        let webhookToken: String?
        let webhookPath: String?
        let webhookUrl: String?
        let label: String?
        let lastFiredAt: String?
        let createdAt: String
        let updatedAt: String
        enum CodingKeys: String, CodingKey {
            case id
            case autopilotId = "autopilot_id"
            case kind
            case enabled
            case cronExpression = "cron_expression"
            case timezone
            case nextRunAt = "next_run_at"
            case webhookToken = "webhook_token"
            case webhookPath = "webhook_path"
            case webhookUrl = "webhook_url"
            case label
            case lastFiredAt = "last_fired_at"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    /// Mirrors `AutopilotRun` from packages/core/types.
    /// Generated — do not edit by hand. Run `pnpm --filter @multica/ios codegen`.
    struct AutopilotRun: Codable, Identifiable, Hashable, Sendable {
        let id: String
        let autopilotId: String
        let triggerId: String?
        let source: AnyCodable
        let status: AnyCodable
        let issueId: String?
        let taskId: String?
        let triggeredAt: String
        let completedAt: String?
        let failureReason: String?
        let triggerPayload: AnyCodable
        let result: AnyCodable
        let createdAt: String
        enum CodingKeys: String, CodingKey {
            case id
            case autopilotId = "autopilot_id"
            case triggerId = "trigger_id"
            case source
            case status
            case issueId = "issue_id"
            case taskId = "task_id"
            case triggeredAt = "triggered_at"
            case completedAt = "completed_at"
            case failureReason = "failure_reason"
            case triggerPayload = "trigger_payload"
            case result
            case createdAt = "created_at"
        }
    }
}
