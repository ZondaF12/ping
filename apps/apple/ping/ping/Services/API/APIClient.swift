import Foundation

protocol APIClientProtocol {
    func postRegister(
        body: RegisterRequestBody,
        cloudKitToken: String
    ) async throws

    func getEndpoints(cloudKitToken: String) async throws -> EndpointResponse

    func postNotify(secret: String, payload: NotifyPayload) async throws -> Bool
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

    func getEndpoints(cloudKitToken: String) async throws -> EndpointResponse {
        let url = URL(string: "\(AppConfig.apiBase)/v1/me/endpoints")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(cloudKitToken, forHTTPHeaderField: "X-CloudKit-Web-Auth-Token")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "ping.api", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Get endpoints failed"
            ])
        }
        return try JSONDecoder().decode(EndpointResponse.self, from: data)
    }

    func postNotify(secret: String, payload: NotifyPayload) async throws -> Bool {
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
