import Foundation

/// Public API list prices in US dollars per million tokens.
public struct ModelPrice: Sendable, Hashable {
    public var input: Double
    public var output: Double
    public var cacheRead: Double
    public var cacheWrite: Double

    /// Cache reads cost a tenth of input and cache writes a quarter more, unless the model says otherwise.
    public init(input: Double, output: Double, cacheRead: Double? = nil, cacheWrite: Double? = nil) {
        self.input = input
        self.output = output
        self.cacheRead = cacheRead ?? input * 0.1
        self.cacheWrite = cacheWrite ?? input * 1.25
    }

    public func cost(of tokens: TokenTotals) -> Double {
        let perToken = 1 / 1_000_000.0
        return (Double(tokens.input) * input
            + Double(tokens.output) * output
            + Double(tokens.cacheRead) * cacheRead
            + Double(tokens.cacheWrite) * cacheWrite) * perToken
    }
}

/// The one place Flightdeck keeps model prices. Costs built from it are estimates of what the same
/// tokens would cost on the pay-as-you-go API, not what a subscription is billed.
public enum PriceTable {
    public static let reviewedOn = "2026-11-06"

    /// Model id prefixes; the longest matching prefix wins, so dated and suffixed ids still match.
    static let prices: [String: ModelPrice] = [
        "claude-fable-5-1": ModelPrice(input: 10, output: 50, cacheRead: 0.25),
        "claude-fable": ModelPrice(input: 10, output: 50),
        "claude-mythos": ModelPrice(input: 10, output: 50),
        "claude-opus-5-5": ModelPrice(input: 4, output: 20, cacheRead: 0.2),
        "claude-opus-5": ModelPrice(input: 5, output: 25),
        "claude-opus-4-8": ModelPrice(input: 5, output: 25),
        "claude-opus-4-7": ModelPrice(input: 5, output: 25),
        "claude-opus-4-6": ModelPrice(input: 5, output: 25),
        "claude-opus-4-5": ModelPrice(input: 5, output: 25),
        "claude-opus-4": ModelPrice(input: 15, output: 75),
        "claude-sonnet-5-5": ModelPrice(input: 2, output: 10, cacheRead: 0.2),
        "claude-sonnet-5": ModelPrice(input: 2, output: 10),
        "claude-sonnet-4": ModelPrice(input: 3, output: 15),
        "claude-3-7-sonnet": ModelPrice(input: 3, output: 15),
        "claude-haiku-5-5": ModelPrice(input: 0.1, output: 0.5),
        "claude-haiku-4-5": ModelPrice(input: 1, output: 5),
        "claude-3-5-haiku": ModelPrice(input: 0.8, output: 4),
        "gpt-5.2": ModelPrice(input: 1.75, output: 14, cacheRead: 0.175, cacheWrite: 0),
        "gpt-5-mini": ModelPrice(input: 0.25, output: 2, cacheRead: 0.025, cacheWrite: 0),
        "gpt-5": ModelPrice(input: 1.25, output: 10, cacheRead: 0.125, cacheWrite: 0),
        "o4-mini": ModelPrice(input: 1.1, output: 4.4, cacheRead: 0.275, cacheWrite: 0),
        "o3": ModelPrice(input: 2, output: 8, cacheRead: 0.5, cacheWrite: 0),
        "gpt-4.1": ModelPrice(input: 2, output: 8, cacheRead: 0.5, cacheWrite: 0),
    ]

    /// Nil for models the table does not know; their tokens are counted but not priced.
    public static func price(forModel model: String?) -> ModelPrice? {
        guard let model = model?.lowercased() else { return nil }
        let match = prices.keys.filter { model.hasPrefix($0) }.max { $0.count < $1.count }
        return match.flatMap { prices[$0] }
    }
}
