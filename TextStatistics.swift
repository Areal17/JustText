//
//  TextStatistics.swift
//  JustText
//
//  Calculates document statistics for the inspector.
//

import Foundation
import NaturalLanguage

struct TextStatistics {
    let characterCount: Int
    let characterCountWithoutWhitespace: Int
    let wordCount: Int
    let lineCount: Int
    let paragraphCount: Int
    let sentenceCount: Int
    let readingTimeMinutes: Int
    let speakingTimeMinutes: Int

    init(text: String) {
        characterCount = text.count
        characterCountWithoutWhitespace = text.unicodeScalars.count { scalar in
            !CharacterSet.whitespacesAndNewlines.contains(scalar)
        }
        wordCount = Self.countTokens(in: text, unit: .word)
        lineCount = text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count
        paragraphCount = text.split(whereSeparator: \.isNewline).count { paragraph in
            paragraph.contains { !$0.isWhitespace }
        }
        sentenceCount = Self.countTokens(in: text, unit: .sentence)
        readingTimeMinutes = Self.estimatedMinutes(wordCount: wordCount, wordsPerMinute: 200)
        speakingTimeMinutes = Self.estimatedMinutes(wordCount: wordCount, wordsPerMinute: 150)
    }

    private static func countTokens(in text: String, unit: NLTokenUnit) -> Int {
        let tokenizer = NLTokenizer(unit: unit)
        tokenizer.string = text

        return tokenizer.tokens(for: text.startIndex..<text.endIndex).count { range in
            text[range].contains { character in
                character.isLetter || character.isNumber
            }
        }
    }

    private static func estimatedMinutes(wordCount: Int, wordsPerMinute: Int) -> Int {
        guard wordCount > 0 else {
            return 0
        }

        return max(1, Int(ceil(Double(wordCount) / Double(wordsPerMinute))))
    }
}
