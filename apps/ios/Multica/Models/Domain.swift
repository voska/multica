import Foundation
import SwiftUI

enum IssueStatus: String, CaseIterable, Identifiable, Sendable {
    case backlog, todo, inProgress = "in_progress", inReview = "in_review", done, blocked, cancelled

    var id: String { rawValue }
    var title: LocalizedStringResource {
        switch self {
        case .backlog: "Backlog"
        case .todo: "Todo"
        case .inProgress: "In Progress"
        case .inReview: "In Review"
        case .done: "Done"
        case .blocked: "Blocked"
        case .cancelled: "Cancelled"
        }
    }
    /// Mirrors STATUS_CONFIG.iconColor from packages/core/issues/config/status.ts
    var tint: Color {
        switch self {
        case .backlog, .todo, .cancelled: MulticaTheme.mutedForeground
        case .inProgress: MulticaTheme.warning
        case .inReview: MulticaTheme.success
        case .done: MulticaTheme.info
        case .blocked: MulticaTheme.danger
        }
    }
    /// Visual progress (0…1) for the pie-style glyph
    var progress: Double {
        switch self {
        case .backlog: 0
        case .todo: 0
        case .inProgress: 0.5
        case .inReview: 0.75
        case .done: 1
        case .blocked: 0
        case .cancelled: 0
        }
    }
    var isOpen: Bool { self != .done && self != .cancelled }

    static let workflowOrder: [IssueStatus] = [.backlog, .todo, .inProgress, .inReview, .done, .blocked, .cancelled]
    static let openOrder: [IssueStatus] = [.inProgress, .inReview, .blocked, .todo, .backlog]

    static func from(_ raw: String?) -> IssueStatus {
        guard let raw, let value = IssueStatus(rawValue: raw) else { return .todo }
        return value
    }
}

enum IssuePriority: String, CaseIterable, Identifiable, Sendable, Comparable {
    case urgent, high, medium, low, none

    var id: String { rawValue }
    var title: LocalizedStringResource {
        switch self {
        case .urgent: "Urgent"
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        case .none: "No priority"
        }
    }
    var systemImage: String {
        switch self {
        case .urgent: "exclamationmark.octagon.fill"
        case .high: "chevron.up.square.fill"
        case .medium: "equal.square.fill"
        case .low: "chevron.down.square"
        case .none: "minus.square"
        }
    }
    var tint: Color {
        switch self {
        case .urgent: MulticaTheme.danger
        case .high: MulticaTheme.warning
        case .medium: MulticaTheme.brand
        case .low, .none: MulticaTheme.mutedForeground
        }
    }
    var rank: Int {
        switch self {
        case .urgent: 0; case .high: 1; case .medium: 2; case .low: 3; case .none: 4
        }
    }
    static func < (lhs: IssuePriority, rhs: IssuePriority) -> Bool { lhs.rank < rhs.rank }
    static func from(_ raw: String?) -> IssuePriority {
        guard let raw, let value = IssuePriority(rawValue: raw) else { return .none }
        return value
    }
}

enum ProjectStatus: String, CaseIterable, Identifiable, Sendable {
    case planned, inProgress = "in_progress", paused, completed, cancelled

    var id: String { rawValue }
    var title: LocalizedStringResource {
        switch self {
        case .planned: "Planned"
        case .inProgress: "Active"
        case .paused: "Paused"
        case .completed: "Completed"
        case .cancelled: "Cancelled"
        }
    }
    var systemImage: String {
        switch self {
        case .planned: "calendar"
        case .inProgress: "play.fill"
        case .paused: "pause"
        case .completed: "checkmark.seal.fill"
        case .cancelled: "xmark.seal"
        }
    }
    var tint: Color {
        switch self {
        case .planned: MulticaTheme.mutedForeground
        case .inProgress: MulticaTheme.brand
        case .paused: MulticaTheme.warning
        case .completed: MulticaTheme.success
        case .cancelled: MulticaTheme.danger
        }
    }
    static func from(_ raw: String?) -> ProjectStatus {
        guard let raw, let value = ProjectStatus(rawValue: raw) else { return .planned }
        return value
    }
}

enum AgentRuntimeStatus: String, CaseIterable, Sendable {
    case online, idle, working, dispatched, offline, error, unknown

    var title: LocalizedStringResource {
        switch self {
        case .online: "Online"
        case .idle: "Idle"
        case .working: "Working"
        case .dispatched: "Dispatched"
        case .offline: "Offline"
        case .error: "Error"
        case .unknown: "Unknown"
        }
    }
    var tint: Color {
        switch self {
        case .online, .idle: MulticaTheme.success
        case .working, .dispatched: MulticaTheme.warning
        case .offline, .unknown: MulticaTheme.mutedForeground
        case .error: MulticaTheme.danger
        }
    }
    var isLive: Bool { self == .working || self == .dispatched }
    static func from(_ raw: String?) -> AgentRuntimeStatus {
        guard let raw else { return .unknown }
        return AgentRuntimeStatus(rawValue: raw) ?? .unknown
    }
}

enum AutopilotStatus: String, CaseIterable, Sendable {
    case active, paused, archived

    var title: LocalizedStringResource {
        switch self {
        case .active: "Active"
        case .paused: "Paused"
        case .archived: "Archived"
        }
    }
    var tint: Color {
        switch self {
        case .active: MulticaTheme.success
        case .paused: MulticaTheme.warning
        case .archived: MulticaTheme.mutedForeground
        }
    }
    var systemImage: String {
        switch self {
        case .active: "bolt.fill"
        case .paused: "pause.fill"
        case .archived: "archivebox"
        }
    }
    static func from(_ raw: String?) -> AutopilotStatus {
        guard let raw, let v = AutopilotStatus(rawValue: raw) else { return .paused }
        return v
    }
}

enum AutopilotRunStatus: String, CaseIterable, Sendable {
    case issueCreated = "issue_created", running, skipped, completed, failed

    var title: LocalizedStringResource {
        switch self {
        case .issueCreated: "Issue created"
        case .running: "Running"
        case .skipped: "Skipped"
        case .completed: "Completed"
        case .failed: "Failed"
        }
    }
    var tint: Color {
        switch self {
        case .issueCreated: MulticaTheme.info
        case .running: MulticaTheme.warning
        case .skipped: MulticaTheme.mutedForeground
        case .completed: MulticaTheme.success
        case .failed: MulticaTheme.danger
        }
    }
    var systemImage: String {
        switch self {
        case .issueCreated: "doc.badge.plus"
        case .running: "circle.dotted"
        case .skipped: "forward.fill"
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }
    static func from(_ raw: String?) -> AutopilotRunStatus {
        guard let raw, let v = AutopilotRunStatus(rawValue: raw) else { return .running }
        return v
    }
}

extension Issue {
    var statusEnum: IssueStatus { IssueStatus.from(status) }
    var priorityEnum: IssuePriority { IssuePriority.from(priority) }
    var isOpen: Bool { statusEnum.isOpen }
}

extension Project {
    var statusEnum: ProjectStatus { ProjectStatus.from(status) }
    var priorityEnum: IssuePriority { IssuePriority.from(priority) }
    var progress: Double {
        let total = max(issueCount ?? 0, 1)
        return Double(doneCount ?? 0) / Double(total)
    }
}

extension Agent {
    var statusEnum: AgentRuntimeStatus { AgentRuntimeStatus.from(status) }
    var isArchived: Bool { archivedAt != nil }
}

extension Squad {
    var isArchived: Bool { archivedAt != nil }
}

extension Autopilot {
    var statusEnum: AutopilotStatus { AutopilotStatus.from(status) }
    var isActive: Bool { statusEnum == .active }
}

extension AutopilotRun {
    var statusEnum: AutopilotRunStatus { AutopilotRunStatus.from(status) }
}
