import Foundation

/// Canonical company display names + fuzzy match against existing records.
public enum CompanyNameNormalizer {
    /// Spoken / lowercase forms → official display (English + 常用中文名).
    public static let aliases: [String: String] = [
        "deepseek": "DeepSeek",
        "deep seek": "DeepSeek",
        "深度求索": "DeepSeek",
        "moonshot": "Moonshot（月之暗面）",
        "moonshot ai": "Moonshot（月之暗面）",
        "月之暗面": "Moonshot（月之暗面）",
        "kimi": "Moonshot（月之暗面）",
        "openai": "OpenAI",
        "anthropic": "Anthropic",
        "claude": "Anthropic",
        "google": "Google",
        "google deepmind": "Google DeepMind",
        "deepmind": "Google DeepMind",
        "meta": "Meta",
        "facebook": "Meta",
        "apple": "Apple",
        "microsoft": "Microsoft",
        "msft": "Microsoft",
        "amazon": "Amazon",
        "aws": "Amazon",
        "nvidia": "NVIDIA",
        "nvdia": "NVIDIA",
        "英伟达": "NVIDIA",
        "字节": "ByteDance（字节跳动）",
        "字节跳动": "ByteDance（字节跳动）",
        "bytedance": "ByteDance（字节跳动）",
        "tiktok": "TikTok",
        "阿里": "Alibaba（阿里巴巴）",
        "alibaba": "Alibaba（阿里巴巴）",
        "腾讯": "Tencent（腾讯）",
        "tencent": "Tencent（腾讯）",
        "美团": "Meituan（美团）",
        "meituan": "Meituan（美团）",
        "sierra": "Sierra",
        "basis": "Basis AI",
        "basis ai": "Basis AI",
        "basisai": "Basis AI"
    ]

    /// Strip "（中文）" / "(Chinese)" for matching keys.
    public static func coreName(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = s.range(of: "（") {
            s = String(s[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        } else if let range = s.range(of: "(") {
            s = String(s[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return s
    }

    public static func matchingKey(_ raw: String) -> String {
        coreName(raw).lowercased()
    }

    /// Short label for charts (English core only).
    public static func chartLabel(_ raw: String) -> String {
        let core = coreName(raw)
        return core.isEmpty ? raw : core
    }

    public static func canonicalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        let key = matchingKey(trimmed)
        if let official = aliases[key] { return official }
        if let official = aliases[trimmed.lowercased()] { return official }
        // Already bilingual / mixed — keep if core has known alias upgrade
        if let official = aliases[matchingKey(trimmed)] { return official }
        if trimmed == trimmed.lowercased(), trimmed.count > 1 {
            return trimmed.prefix(1).uppercased() + trimmed.dropFirst()
        }
        return trimmed
    }

    /// Match against existing company names (case-insensitive / alias / close typo).
    public static func resolve(
        raw: String,
        existingNames: [String]
    ) -> ResolvedName {
        let canonical = canonicalize(raw)
        let rawKey = matchingKey(raw)

        if let existing = existingNames.first(where: { matchingKey($0) == matchingKey(canonical) || matchingKey($0) == rawKey }) {
            let upgraded = canonicalize(existing)
            // Prefer richer official display when we know it
            if aliases[matchingKey(existing)] != nil || aliases[rawKey] != nil {
                return .matched(canonical)
            }
            return .matched(upgraded == existing ? existing : upgraded)
        }

        if aliases[rawKey] != nil {
            return .matched(aliases[rawKey]!)
        }

        // Close typo against existing
        if let close = existingNames.first(where: {
            levenshtein(rawKey, matchingKey($0)) == 1 && rawKey.count >= 4
        }) {
            return .needsConfirmation(typed: raw, suggestion: canonicalize(close))
        }

        // Close typo against known alias targets
        for (alias, official) in aliases {
            if levenshtein(rawKey, alias) == 1 && rawKey.count >= 4 {
                return .needsConfirmation(typed: raw, suggestion: official)
            }
            if levenshtein(rawKey, matchingKey(official)) == 1 && rawKey.count >= 4 {
                return .needsConfirmation(typed: raw, suggestion: official)
            }
        }

        return .matched(canonical)
    }

    public enum ResolvedName: Equatable, Sendable {
        case matched(String)
        case needsConfirmation(typed: String, suggestion: String)
    }

    public static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        var cur = Array(repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            cur[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            }
            prev = cur
        }
        return prev[b.count]
    }
}
