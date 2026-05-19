import SwiftUI

// MARK: - Status icon (mirrors packages/views/issues/components/status-icon.tsx)

/// Issue status glyph — pie ring matching the webapp:
/// backlog = dotted ring, todo = empty ring, in_progress = half pie,
/// in_review = 3/4 pie, done = filled, blocked = "!" badge, cancelled = "✕" badge.
struct IssueStatusIcon: View {
    let status: IssueStatus
    var size: CGFloat = 14

    var body: some View {
        Group {
            switch status {
            case .backlog: BacklogGlyph()
            case .todo: ProgressGlyph(progress: 0)
            case .inProgress: ProgressGlyph(progress: 0.5)
            case .inReview: ProgressGlyph(progress: 0.75)
            case .done: ProgressGlyph(progress: 1)
            case .blocked: BlockedGlyph()
            case .cancelled: CancelledGlyph()
            }
        }
        .frame(width: size, height: size)
        .foregroundStyle(status.tint)
        .accessibilityLabel(Text(status.title))
    }

    private struct ProgressGlyph: View {
        let progress: Double
        var body: some View {
            GeometryReader { proxy in
                let s = min(proxy.size.width, proxy.size.height)
                let outerR = s * 0.42
                let innerR = s * 0.25
                ZStack {
                    Circle().stroke(.currentColor, lineWidth: max(1, s * 0.10))
                        .frame(width: outerR * 2, height: outerR * 2)
                    if progress >= 1 {
                        Circle().fill(.currentColor)
                            .frame(width: outerR * 2, height: outerR * 2)
                    } else if progress > 0 {
                        PieShape(progress: progress)
                            .fill(.currentColor)
                            .frame(width: innerR * 2, height: innerR * 2)
                    }
                }
                .frame(width: s, height: s)
            }
        }
    }

    private struct BacklogGlyph: View {
        var body: some View {
            GeometryReader { proxy in
                let s = min(proxy.size.width, proxy.size.height)
                let r = s * 0.42
                let count = 12
                let dot = s * 0.07
                ZStack {
                    ForEach(0..<count, id: \.self) { i in
                        let angle = Double(i) / Double(count) * 2 * .pi
                        Circle().fill(.currentColor)
                            .frame(width: dot, height: dot)
                            .offset(x: cos(angle) * r, y: sin(angle) * r)
                    }
                }
                .frame(width: s, height: s)
            }
        }
    }

    private struct BlockedGlyph: View {
        var body: some View {
            GeometryReader { proxy in
                let s = min(proxy.size.width, proxy.size.height)
                ZStack {
                    Circle().fill(.currentColor)
                    Image(systemName: "exclamationmark")
                        .resizable().scaledToFit()
                        .foregroundStyle(.white)
                        .frame(width: s * 0.35, height: s * 0.55)
                }
                .frame(width: s, height: s)
            }
        }
    }

    private struct CancelledGlyph: View {
        var body: some View {
            GeometryReader { proxy in
                let s = min(proxy.size.width, proxy.size.height)
                ZStack {
                    Circle().stroke(.currentColor, lineWidth: max(1, s * 0.10))
                    Image(systemName: "xmark")
                        .resizable().scaledToFit()
                        .foregroundStyle(.currentColor)
                        .frame(width: s * 0.45, height: s * 0.45)
                }
                .frame(width: s, height: s)
            }
        }
    }
}

extension ShapeStyle where Self == HierarchicalShapeStyle {
    static var currentColor: HierarchicalShapeStyle { .primary }
}

/// Pie wedge starting at 12 o'clock, sweeping clockwise.
struct PieShape: Shape {
    var progress: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let start = Angle(degrees: -90)
        let end = Angle(degrees: -90 + 360 * progress)
        p.move(to: center)
        p.addLine(to: CGPoint(x: center.x, y: center.y - radius))
        p.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        p.closeSubpath()
        return p
    }
}

// MARK: - Avatars

struct WorkspaceAvatar: View {
    let name: String
    let url: URL?
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .fill(MulticaTheme.brand.gradient)
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Text(name.first.map(String.init)?.uppercased() ?? "M")
                            .font(.system(size: size * 0.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
            } else {
                Text(name.first.map(String.init)?.uppercased() ?? "M")
                    .font(.system(size: size * 0.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}

struct ActorAvatar: View {
    let name: String
    let url: URL?
    var size: CGFloat = 28
    var isAgent: Bool = false

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init)
        return letters.joined().uppercased().nilIfEmpty ?? String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            Circle().fill(isAgent ? MulticaTheme.brand.opacity(0.18) : MulticaTheme.muted)
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        label
                    }
                }
                .clipShape(Circle())
            } else {
                label
            }
            if isAgent {
                Image(systemName: "bolt.fill")
                    .resizable().scaledToFit()
                    .foregroundStyle(MulticaTheme.brand)
                    .frame(width: size * 0.32, height: size * 0.32)
                    .offset(x: size * 0.32, y: size * 0.32)
            }
        }
        .frame(width: size, height: size)
    }

    private var label: some View {
        Text(initials)
            .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
            .foregroundStyle(isAgent ? MulticaTheme.brand : MulticaTheme.mutedForeground)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Badges

struct PriorityChip: View {
    let priority: IssuePriority
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: priority.systemImage)
                .imageScale(.small)
            Text(priority.title)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(priority.tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(priority.tint.opacity(0.12), in: Capsule())
        .accessibilityLabel(Text(priority.title))
    }
}

struct StatusChip: View {
    let status: IssueStatus
    var body: some View {
        HStack(spacing: 5) {
            IssueStatusIcon(status: status, size: 11)
            Text(status.title)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(status.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(status.tint.opacity(0.10), in: Capsule())
        .accessibilityLabel(Text(status.title))
    }
}

struct AgentLiveDot: View {
    let isLive: Bool
    var body: some View {
        Circle()
            .fill(isLive ? MulticaTheme.warning : MulticaTheme.mutedForeground.opacity(0.4))
            .frame(width: 7, height: 7)
            .overlay(
                Circle()
                    .stroke(isLive ? MulticaTheme.warning.opacity(0.4) : .clear, lineWidth: 4)
                    .scaleEffect(isLive ? 1.8 : 1)
                    .opacity(isLive ? 0 : 0.5)
                    .animation(
                        isLive ? .easeOut(duration: 1.4).repeatForever(autoreverses: false) : .default,
                        value: isLive
                    )
            )
    }
}

// MARK: - Button styles

struct PrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView().controlSize(.small).tint(.white)
            }
            configuration.label
                .font(.body.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .foregroundStyle(.white)
        .background(MulticaTheme.brand, in: RoundedRectangle(cornerRadius: MulticaTheme.radius, style: .continuous))
        .opacity(configuration.isPressed ? 0.85 : 1)
        .scaleEffect(configuration.isPressed ? 0.985 : 1)
        .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(.primary)
            .background(MulticaTheme.muted, in: RoundedRectangle(cornerRadius: MulticaTheme.radius, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - Surfaces

extension View {
    func cardSurface(padding: CGFloat = 14) -> some View {
        self
            .padding(padding)
            .background(.background, in: RoundedRectangle(cornerRadius: MulticaTheme.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MulticaTheme.radius, style: .continuous)
                    .strokeBorder(MulticaTheme.border, lineWidth: 0.5)
            }
    }
}

// MARK: - Onboarding hero + form pieces

struct OnboardingHero: View {
    let systemImage: String
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource?

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(MulticaTheme.brand.gradient)
                    .frame(width: 76, height: 76)
                Image(systemName: systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
            }
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                if let subtitle {
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
            }
        }
        .padding(.top, 12)
    }
}

struct StepIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? MulticaTheme.brand : MulticaTheme.muted)
                    .frame(width: index == current ? 22 : 8, height: 6)
                    .animation(.snappy, value: current)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Step \(current + 1) of \(total)"))
    }
}

struct InlineError: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(MulticaTheme.danger)
                .accessibilityHidden(true)
            Text(message)
                .font(.callout)
                .foregroundStyle(MulticaTheme.danger)
        }
        .accessibilityElement(children: .combine)
    }
}

struct LoadingScreen: View {
    let message: LocalizedStringResource

    var body: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large)
            Text(message).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

// MARK: - Empty + error

struct EmptyState: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let systemImage: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }
}

// MARK: - Date formatting helpers

enum MulticaTime {
    static func relativeShort(from raw: String?) -> String? {
        guard let date = MulticaDate.parse(raw) else { return nil }
        let now = Date()
        let interval = now.timeIntervalSince(date)
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        if interval < 86400 * 7 { return "\(Int(interval / 86400))d" }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    enum Bucket: String, CaseIterable {
        case today, yesterday, thisWeek, earlier

        var title: LocalizedStringResource {
            switch self {
            case .today: "Today"
            case .yesterday: "Yesterday"
            case .thisWeek: "This week"
            case .earlier: "Earlier"
            }
        }
    }

    static func bucket(_ raw: String?, now: Date = Date()) -> Bucket {
        guard let date = MulticaDate.parse(raw) else { return .earlier }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return .today }
        if cal.isDateInYesterday(date) { return .yesterday }
        if let weekAgo = cal.date(byAdding: .day, value: -7, to: now), date > weekAgo { return .thisWeek }
        return .earlier
    }
}
