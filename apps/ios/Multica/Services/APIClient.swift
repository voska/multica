import Foundation

protocol APIClientSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: APIClientSession {}

struct APIClient: Sendable {
    var baseURL: URL
    var token: String?
    var workspaceID: String?
    var version: String
    var session: any APIClientSession

    init(
        baseURL: URL,
        token: String? = nil,
        workspaceID: String? = nil,
        version: String = "0.1.0",
        session: any APIClientSession = URLSession.shared
    ) {
        self.baseURL = baseURL
        self.token = token
        self.workspaceID = workspaceID
        self.version = version
        self.session = session
    }

    enum APIError: LocalizedError, Equatable {
        case invalidURL(String)
        case emptyResponse
        case unauthorized(String)
        case http(Int, String)

        var errorDescription: String? {
            switch self {
            case .invalidURL(let path): "Invalid API path: \(path)"
            case .emptyResponse: "The server returned an empty response."
            case .unauthorized(let message): message.isEmpty ? "Your session expired. Please sign in again." : message
            case .http(let status, let message): "HTTP \(status): \(message)"
            }
        }
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }

    func sendCode(email: String) async throws {
        let payload = SendCodePayload(email: email)
        let _: EmptyResponse = try await request("/auth/send-code", method: "POST", body: payload, requiresAuth: false)
    }

    func verifyCode(email: String, code: String) async throws -> LoginResponse {
        try await request("/auth/verify-code", method: "POST", body: VerifyCodePayload(email: email, code: code), requiresAuth: false)
    }

    func logout() async throws {
        let _: EmptyResponse = try await request("/auth/logout", method: "POST", body: EmptyBody())
    }

    func getMe() async throws -> User { try await request("/api/me") }
    func listWorkspaces() async throws -> [Workspace] { try await request("/api/workspaces") }

    func listIssues(workspaceID: String, openOnly: Bool = false) async throws -> ListIssuesResponse {
        var query = [URLQueryItem(name: "workspace_id", value: workspaceID), URLQueryItem(name: "limit", value: "100")]
        if openOnly { query.append(URLQueryItem(name: "open_only", value: "true")) }
        return try await request("/api/issues", query: query)
    }

    func getIssue(_ id: String) async throws -> Issue { try await request("/api/issues/\(id)") }

    func createIssue(_ payload: CreateIssuePayload) async throws -> Issue {
        try await request("/api/issues", method: "POST", body: payload)
    }

    func updateIssue(_ id: String, payload: UpdateIssuePayload) async throws -> Issue {
        try await request("/api/issues/\(id)", method: "PUT", body: payload)
    }

    func listComments(issueID: String) async throws -> [Comment] {
        try await request("/api/issues/\(issueID)/comments")
    }

    func createComment(issueID: String, content: String) async throws -> Comment {
        try await request("/api/issues/\(issueID)/comments", method: "POST", body: CreateCommentPayload(content: content, type: "comment"))
    }

    func listInbox() async throws -> [InboxItem] { try await request("/api/inbox") }

    func getUnreadInboxCount() async throws -> CountResponse { try await request("/api/inbox/unread-count") }

    func markInboxRead(_ id: String) async throws -> InboxItem {
        try await request("/api/inbox/\(id)/read", method: "POST", body: EmptyBody())
    }

    func archiveInbox(_ id: String) async throws -> InboxItem {
        try await request("/api/inbox/\(id)/archive", method: "POST", body: EmptyBody())
    }

    func listAgents(workspaceID: String) async throws -> [Agent] {
        try await request("/api/agents", query: [URLQueryItem(name: "workspace_id", value: workspaceID)])
    }

    func listProjects(workspaceID: String) async throws -> ListProjectsResponse {
        try await request("/api/projects", query: [URLQueryItem(name: "workspace_id", value: workspaceID)])
    }

    func getProject(_ id: String) async throws -> Project { try await request("/api/projects/\(id)") }

    func createProject(_ payload: CreateProjectPayload) async throws -> Project {
        try await request("/api/projects", method: "POST", body: payload)
    }

    func updateProject(_ id: String, payload: UpdateProjectPayload) async throws -> Project {
        try await request("/api/projects/\(id)", method: "PUT", body: payload)
    }

    func listProjectResources(projectID: String) async throws -> ListProjectResourcesResponse {
        try await request("/api/projects/\(projectID)/resources")
    }

    func listSquads() async throws -> [Squad] { try await request("/api/squads") }

    func listAutopilots(status: String? = nil) async throws -> ListAutopilotsResponse {
        var query: [URLQueryItem] = []
        if let status { query.append(URLQueryItem(name: "status", value: status)) }
        return try await request("/api/autopilots", query: query)
    }

    func getAutopilot(_ id: String) async throws -> GetAutopilotResponse {
        try await request("/api/autopilots/\(id)")
    }

    func updateAutopilot(_ id: String, payload: UpdateAutopilotPayload) async throws -> Autopilot {
        try await request("/api/autopilots/\(id)", method: "PUT", body: payload)
    }

    func triggerAutopilot(_ id: String) async throws -> AutopilotRun {
        try await request("/api/autopilots/\(id)/trigger", method: "POST", body: EmptyBody())
    }

    func listAutopilotRuns(_ id: String, limit: Int = 20) async throws -> ListAutopilotRunsResponse {
        try await request("/api/autopilots/\(id)/runs", query: [URLQueryItem(name: "limit", value: String(limit))])
    }

    func getSquad(_ id: String) async throws -> Squad { try await request("/api/squads/\(id)") }

    func listSquadMembers(squadID: String) async throws -> [SquadMember] {
        try await request("/api/squads/\(squadID)/members")
    }

    private func request<T: Decodable>(_ path: String, query: [URLQueryItem] = [], requiresAuth: Bool = true) async throws -> T {
        try await request(path, method: "GET", query: query, bodyData: nil, requiresAuth: requiresAuth)
    }

    private func request<T: Decodable, Body: Encodable>(
        _ path: String,
        method: String,
        query: [URLQueryItem] = [],
        body: Body,
        requiresAuth: Bool = true
    ) async throws -> T {
        let bodyData = Body.self == EmptyBody.self ? nil : try encoder.encode(body)
        return try await request(path, method: method, query: query, bodyData: bodyData, requiresAuth: requiresAuth)
    }

    private func request<T: Decodable>(
        _ path: String,
        method: String,
        query: [URLQueryItem],
        bodyData: Data?,
        requiresAuth: Bool
    ) async throws -> T {
        let request = try makeRequest(path: path, method: method, query: query, bodyData: bodyData, requiresAuth: requiresAuth)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.emptyResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = APIClient.errorMessage(from: data) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            if http.statusCode == 401 { throw APIError.unauthorized(message) }
            throw APIError.http(http.statusCode, message)
        }
        if T.self == EmptyResponse.self || data.isEmpty {
            return EmptyResponse() as! T
        }
        return try decoder.decode(T.self, from: data)
    }

    func makeRequest(
        path: String,
        method: String = "GET",
        query: [URLQueryItem] = [],
        bodyData: Data? = nil,
        requiresAuth: Bool = true
    ) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL(path)
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.invalidURL(path) }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ios", forHTTPHeaderField: "X-Client-Platform")
        request.setValue(version, forHTTPHeaderField: "X-Client-Version")
        request.setValue("iOS", forHTTPHeaderField: "X-Client-OS")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        request.setValue("Multica iOS/\(version)", forHTTPHeaderField: "User-Agent")
        if requiresAuth, let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let workspaceID { request.setValue(workspaceID, forHTTPHeaderField: "X-Workspace-ID") }
        request.httpBody = bodyData
        return request
    }

    private static func errorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? String { return error }
            if let message = json["message"] as? String { return message }
        }
        return String(data: data, encoding: .utf8)
    }
}

struct EmptyBody: Encodable, Sendable {}
struct EmptyResponse: Decodable, Sendable {}
