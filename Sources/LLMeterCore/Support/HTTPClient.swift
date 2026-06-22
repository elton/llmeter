import Foundation

public struct HTTPRequest: Sendable {
    public var url: URL
    public var headers: [String: String]

    public init(url: URL, headers: [String: String] = [:]) {
        self.url = url
        self.headers = headers
    }
}

public protocol HTTPClient: Sendable {
    func get(_ request: HTTPRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionHTTPClient: HTTPClient {
    let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public static func makeURLRequest(_ request: HTTPRequest) -> URLRequest {
        var req = URLRequest(url: request.url)
        req.httpMethod = "GET"
        for (key, value) in request.headers {
            req.setValue(value, forHTTPHeaderField: key)
        }
        return req
    }

    public func get(_ request: HTTPRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: Self.makeURLRequest(request))
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}
