import Foundation

public struct CloudFailure: LocalizedError, Codable, Sendable {
  public let code: String
  public let message: String
  public let retryable: Bool
  public var errorDescription: String? { message }
  public init(code: String, message: String, retryable: Bool) {
    self.code = code
    self.message = message
    self.retryable = retryable
  }
}
public protocol ProjectCloudClient: Sendable {
  func projects(accessToken: String) async throws -> [Project]
  func createProject(title: String, ownerID: UUID, accessToken: String) async throws -> Project
}
public struct SupabaseProjectClient: ProjectCloudClient {
  private let baseURL: URL
  private let publishableKey: String
  public init(baseURL: URL, publishableKey: String) {
    self.baseURL = baseURL
    self.publishableKey = publishableKey
  }
  public func projects(accessToken: String) async throws -> [Project] {
    try await request(method: "GET", token: accessToken, body: nil)
  }
  public func createProject(title: String, ownerID: UUID, accessToken: String) async throws
    -> Project
  {
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else {
      throw CloudFailure(
        code: "invalid_title", message: "A project title is required.", retryable: false)
    }
    let body = try JSONSerialization.data(withJSONObject: [
      "title": title, "owner_id": ownerID.uuidString,
    ])
    let rows: [Project] = try await request(method: "POST", token: accessToken, body: body)
    guard let row = rows.first else {
      throw CloudFailure(
        code: "invalid_response", message: "Cloud returned no project.", retryable: false)
    }
    return row
  }
  private func request(method: String, token: String, body: Data?) async throws -> [Project] {
    var request = URLRequest(
      url: baseURL.appendingPathComponent("rest/v1/projects").appending(queryItems: [
        URLQueryItem(name: "select", value: "*")
      ]))
    request.httpMethod = method
    request.httpBody = body
    request.setValue(publishableKey, forHTTPHeaderField: "apikey")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("return=representation", forHTTPHeaderField: "Prefer")
    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await URLSession.shared.data(for: request)
    } catch is CancellationError { throw CancellationError() } catch {
      throw CloudFailure(
        code: "network_error", message: "Could not reach NTO Cloud. Try again when connected.",
        retryable: true)
    }
    guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode)
    else {
      throw CloudFailure(
        code: (response as? HTTPURLResponse)?.statusCode == 401
          ? "session_expired" : "request_failed",
        message: (response as? HTTPURLResponse)?.statusCode == 401
          ? "Sign in again to continue."
          : "Cloud project request failed. Check the connection and session.",
        retryable: (response as? HTTPURLResponse).map {
          $0.statusCode >= 500 || $0.statusCode == 429
        } ?? true)
    }
    let rows: [ProjectRow]
    do { rows = try JSONDecoder().decode([ProjectRow].self, from: data) } catch {
      throw CloudFailure(
        code: "invalid_response", message: "Cloud returned an unreadable project response.",
        retryable: false)
    }
    return rows.map {
      Project(id: $0.id, ownerId: $0.owner_id, title: $0.title, createdAt: $0.created_at)
    }
  }
  private struct ProjectRow: Decodable {
    let id: UUID
    let owner_id: UUID
    let title: String
    let created_at: String
  }
}
