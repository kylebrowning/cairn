import AsyncHTTPClient
import Foundation
import NIOCore
import NIOHTTP1

/// The one seam between GitHubClient and the network. Tests substitute a
/// fixture-backed transport; production uses AsyncHTTPClient.
public protocol HTTPTransport: Sendable {
    func send(_ request: TransportRequest) async throws -> TransportResponse
}

public struct TransportRequest: Sendable {
    public var method: String
    public var url: String
    public var headers: [(String, String)]
    public var body: Data?

    public init(method: String, url: String, headers: [(String, String)] = [], body: Data? = nil) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

public struct TransportResponse: Sendable {
    public var status: Int
    public var headers: [(String, String)]
    public var body: Data

    public init(status: Int, headers: [(String, String)] = [], body: Data) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    public func header(_ name: String) -> String? {
        headers.first { $0.0.lowercased() == name.lowercased() }?.1
    }
}

public struct AsyncHTTPClientTransport: HTTPTransport {
    let client: HTTPClient

    public init(client: HTTPClient = .shared) {
        self.client = client
    }

    public func send(_ request: TransportRequest) async throws -> TransportResponse {
        var httpRequest = HTTPClientRequest(url: request.url)
        httpRequest.method = .init(rawValue: request.method)
        for (name, value) in request.headers {
            httpRequest.headers.add(name: name, value: value)
        }
        if let body = request.body {
            httpRequest.body = .bytes(ByteBuffer(bytes: body))
        }
        let response = try await client.execute(httpRequest, timeout: .seconds(30))
        let buffer = try await response.body.collect(upTo: 32 * 1024 * 1024)
        let data = Data(buffer.readableBytesView)
        return TransportResponse(
            status: Int(response.status.code),
            headers: response.headers.map { ($0.name, $0.value) },
            body: data
        )
    }
}
