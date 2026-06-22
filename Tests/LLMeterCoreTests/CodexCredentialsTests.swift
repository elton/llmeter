import Testing
import Foundation
@testable import LLMeterCore

struct CodexCredentialsTests {
    private func writeTempAuth(_ contents: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: "auth.json")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test func readsTokenAndAccountId() throws {
        let url = try writeTempAuth(loadFixture("codex-auth.json"))
        let creds = try CodexCredentialsReader.read(authJSONPath: url)
        #expect(creds.accessToken == "fake-access-token-for-tests")
        #expect(creds.accountId == "user-FAKE000000000000000000")
    }

    @Test func throwsWhenTokensMissing() throws {
        let url = try writeTempAuth("{\"auth_mode\":\"chatgpt\"}")
        #expect(throws: CredentialError.missing) {
            try CodexCredentialsReader.read(authJSONPath: url)
        }
    }
}
