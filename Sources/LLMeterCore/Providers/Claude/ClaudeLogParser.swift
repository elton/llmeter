import Foundation

public struct ClaudeUsageEntry: Sendable, Equatable {
    public let timestamp: Date
    public let model: String?
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadTokens: Int
    public let cacheCreationTokens: Int

    public var totalTokens: Int {
        inputTokens + outputTokens + cacheReadTokens + cacheCreationTokens
    }
}

public enum ClaudeLogParser {
    public static func entries(fromJSONL content: String) -> [ClaudeUsageEntry] {
        var result: [ClaudeUsageEntry] = []
        for rawLine in content.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(rawLine.utf8)) as? [String: Any],
                  let tsString = obj["timestamp"] as? String,
                  let timestamp = parseTimestamp(tsString),
                  let message = obj["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any]
            else { continue }

            result.append(ClaudeUsageEntry(
                timestamp: timestamp,
                model: message["model"] as? String,
                inputTokens: usage["input_tokens"] as? Int ?? 0,
                outputTokens: usage["output_tokens"] as? Int ?? 0,
                cacheReadTokens: usage["cache_read_input_tokens"] as? Int ?? 0,
                cacheCreationTokens: usage["cache_creation_input_tokens"] as? Int ?? 0
            ))
        }
        return result
    }

    private static func parseTimestamp(_ string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: string) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}
