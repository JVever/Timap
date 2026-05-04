import Foundation

/// Deterministic initials and palette colors used by avatar fallbacks across
/// teammate chips, edit forms, and member rows. Mirrors the helpers in the
/// `settings-v1d.jsx` design prototype:
///
///   • CJK names: 2 chars → both; 3+ → last two (`欧阳娜娜` → `娜娜`).
///   • Latin names: first letter of first + last word, max 2.
///   • Single Latin word: first two letters, uppercased.
public enum Initials {
    public static func of(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "?" }

        if hasCJK(trimmed) {
            let chars = Array(trimmed)
            return chars.count <= 2 ? String(chars) : String(chars.suffix(2))
        }

        let words = trimmed.split { $0.isWhitespace }
        if words.count >= 2,
           let first = words.first?.first,
           let last = words.last?.first {
            return "\(first)\(last)".uppercased()
        }
        // Single-word fallback: just the first letter. Two-letter slugs
        // like "MA" for "madonna" felt arbitrary — they pretend the user
        // has a surname starting with "A" when they don't.
        if let first = trimmed.first {
            return String(first).uppercased()
        }
        return "?"
    }

    /// True if the string contains a CJK Unified Ideograph (U+4E00–U+9FFF).
    /// We don't try to handle Hangul / Kana — the JSX prototype only checked
    /// CJK and the heuristic produces sensible initials for those scripts via
    /// the Latin path anyway.
    public static func hasCJK(_ s: String) -> Bool {
        for scalar in s.unicodeScalars where (0x4E00...0x9FFF).contains(scalar.value) {
            return true
        }
        return false
    }
}

/// Deterministic palette assignment from a seed string. The 8-color palette
/// matches the design prototype so identities stay visually consistent
/// between mock and live app.
public enum Palette {
    public static let colors: [String] = [
        "#c96442", "#3b7a8c", "#7a5ca8", "#c8924a",
        "#5fcf8a", "#e8b86b", "#c75a92", "#5a8cc7"
    ]

    /// Stable index for a seed string. Matches the JSX implementation:
    ///   `let h = (h * 31 + code) | 0` accumulator, then `abs(h) % palette.length`.
    /// Used for member avatars (seed = teammate id or name) and city pins
    /// for empty cities (seed = city name).
    public static func color(for seed: String) -> String {
        var h: Int32 = 0
        for scalar in seed.unicodeScalars {
            // Match JSX's |0 truncate-to-int32 semantics.
            h = h &* 31 &+ Int32(truncatingIfNeeded: scalar.value)
        }
        let idx = Int(abs(Int(h))) % colors.count
        return colors[idx]
    }
}
