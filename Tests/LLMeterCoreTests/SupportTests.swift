import Testing
import Foundation
@testable import LLMeterCore

struct SupportTests {
    @Test func makeURLRequestSetsMethodAndHeaders() {
        let req = HTTPRequest(url: URL(string: "https://example.com/x")!,
                              headers: ["Authorization": "Bearer abc", "Accept": "application/json"])
        let urlReq = URLSessionHTTPClient.makeURLRequest(req)
        #expect(urlReq.httpMethod == "GET")
        #expect(urlReq.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
        #expect(urlReq.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test func stubHTTPClientReturnsConfiguredResponse() async throws {
        let stub = StubHTTPClient(result: .success((Data("hi".utf8), 200)))
        let (data, resp) = try await stub.get(HTTPRequest(url: URL(string: "https://x")!))
        #expect(String(decoding: data, as: UTF8.self) == "hi")
        #expect(resp.statusCode == 200)
    }

    @Test func stubClockReturnsFixedTime() {
        let t = Date(timeIntervalSince1970: 1_782_104_558)
        #expect(StubClock(now: t).now == t)
    }
}
