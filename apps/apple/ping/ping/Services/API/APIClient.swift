import Foundation

/// `userInfo` key for failed HTTP responses from `getEndpoints` (Int).
enum PingAPIErrorInfo {
    static let httpStatusCode = "HTTPStatusCode"
    static let httpBodySnippet = "HTTPBodySnippet"
}

protocol APIClientProtocol {
    func postRegister(
        body: RegisterRequestBody,
        cloudKitToken: String
    ) async throws

    func getEndpoints(cloudKitToken: String, userRecordName: String?) async throws -> EndpointResponse

    func postNotify(secret: String, payload: String) async throws -> Bool
}

struct APIClient: APIClientProtocol {
    func postRegister(
        body: RegisterRequestBody,
        cloudKitToken: String
    ) async throws {
        let url = URL(string: "\(AppConfig.apiBase)/v1/me/endpoints/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(cloudKitToken, forHTTPHeaderField: "X-CloudKit-Web-Auth-Token")
        request.httpBody = try JSONEncoder().encode(body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "ping.api", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Register failed"
            ])
        }
    }

    func getEndpoints(cloudKitToken: String, userRecordName: String?) async throws -> EndpointResponse {
        let url = URL(string: "\(AppConfig.apiBase)/v1/me/endpoints")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(cloudKitToken, forHTTPHeaderField: "X-CloudKit-Web-Auth-Token")
        if let name = userRecordName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            request.setValue(name, forHTTPHeaderField: "X-User-Record-Name")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "ping.api", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Endpoints failed: not an HTTP response"
            ])
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodySnippet = String(data: data, encoding: .utf8).map { String($0.prefix(500)) } ?? ""
            throw NSError(domain: "ping.api", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Endpoints failed (\(http.statusCode))",
                PingAPIErrorInfo.httpStatusCode: http.statusCode,
                PingAPIErrorInfo.httpBodySnippet: bodySnippet
            ])
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(EndpointResponse.self, from: data)
    }

    func postNotify(secret: String, payload: String) async throws -> Bool {
        let encodedSecret = secret.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? secret
        let url = URL(string: "\(AppConfig.apiBase)/v1/\(encodedSecret)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "ping.api", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Notify failed"
            ])
        }
        guard (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "ping.api", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Notify failed (\(http.statusCode))"
            ])
        }
        let parsed = try JSONDecoder().decode(NotifyResponse.self, from: data)
        return parsed.success
    }
}
