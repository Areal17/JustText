//
//  SearchMatchFinder.swift
//  JustText
//
//  Finds text matches for editor search highlighting.
//

import Foundation

struct SearchMatchFinder {
    static func ranges(of query: String, in text: String) -> [NSRange] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return []
        }

        let source = text as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        var searchRange = fullRange
        var ranges: [NSRange] = []

        while searchRange.length > 0 {
            let range = source.range(
                of: trimmedQuery,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: searchRange
            )
            guard range.location != NSNotFound else {
                break
            }

            ranges.append(range)
            let nextLocation = range.location + max(range.length, 1)
            guard nextLocation <= fullRange.length else {
                break
            }
            searchRange = NSRange(location: nextLocation, length: fullRange.length - nextLocation)
        }

        return ranges
    }
}
