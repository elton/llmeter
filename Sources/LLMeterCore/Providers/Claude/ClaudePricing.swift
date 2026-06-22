import Foundation

public struct ModelPricing: Sendable {
    public let inputPerMTok: Double
    public let outputPerMTok: Double
    public let cacheReadPerMTok: Double
    public let cacheWritePerMTok: Double
}

public enum ClaudePricing {
    // USD per million tokens. Defaults track public Claude API list prices;
    // adjust as Anthropic updates them. Used only for local cost ESTIMATES.
    public static func pricing(for model: String?) -> ModelPricing {
        let name = (model ?? "").lowercased()
        if name.contains("opus") {
            return ModelPricing(inputPerMTok: 15, outputPerMTok: 75, cacheReadPerMTok: 1.5, cacheWritePerMTok: 18.75)
        }
        if name.contains("haiku") {
            return ModelPricing(inputPerMTok: 1, outputPerMTok: 5, cacheReadPerMTok: 0.1, cacheWritePerMTok: 1.25)
        }
        // default: Sonnet
        return ModelPricing(inputPerMTok: 3, outputPerMTok: 15, cacheReadPerMTok: 0.3, cacheWritePerMTok: 3.75)
    }

    public static func cost(_ entry: ClaudeUsageEntry) -> Double {
        let p = pricing(for: entry.model)
        let m = 1_000_000.0
        return Double(entry.inputTokens) / m * p.inputPerMTok
             + Double(entry.outputTokens) / m * p.outputPerMTok
             + Double(entry.cacheReadTokens) / m * p.cacheReadPerMTok
             + Double(entry.cacheCreationTokens) / m * p.cacheWritePerMTok
    }
}
