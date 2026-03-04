//
//  String+ContentParts.swift
//  Chat
//
//  Parses file paths and URLs for images/PDFs from user input text,
//  returning multimodal ContentPart arrays for vision-capable models.
//

import Foundation
import Operator

/// Supported media file extensions for multimodal content detection.
private let mediaExtensions = Set(["jpg", "jpeg", "png", "gif", "webp", "pdf"])

/// Matches absolute paths, tilde paths, and http(s) URLs ending in a media extension.
///
/// Groups:
/// - The full match is the path or URL
private nonisolated(unsafe) let mediaPattern: Regex = {
    let extensions = mediaExtensions.joined(separator: "|")
    // Match: ~/path/to/file.ext, /path/to/file.ext, or https://host/path/file.ext
    return try! Regex(
        #"(?:~/|/|https?://)[^\s]*\.(?:"# + extensions + #")"#,
        as: Substring.self
    ).ignoresCase()
}()

public extension String {
    /// Parses the string for local file paths and remote URLs pointing to
    /// images or PDFs, returning an array of ``ContentPart``s if any media
    /// was found and successfully loaded.
    ///
    /// - Returns: An array of content parts with interleaved text and media,
    ///   or `nil` if no media was detected or loaded.
    func contentParts() -> [ContentPart]? {
        let matches = Array(matches(of: mediaPattern))
        guard !matches.isEmpty else { return nil }

        var parts = [ContentPart]()
        var currentIndex = startIndex
        var loadedMedia = false

        for match in matches {
            let matchRange = match.range

            // Add text before this match
            if currentIndex < matchRange.lowerBound {
                let text = String(self[currentIndex ..< matchRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    parts.append(.text(text))
                }
            }

            // Try to load the media
            let rawPath = String(self[matchRange])
            if let part = loadMediaPart(from: rawPath) {
                parts.append(part)
                loadedMedia = true
            } else {
                // Loading failed — keep as text
                parts.append(.text(rawPath))
            }

            currentIndex = matchRange.upperBound
        }

        // Add trailing text
        if currentIndex < endIndex {
            let text = String(self[currentIndex...])
                .trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                parts.append(.text(text))
            }
        }

        return loadedMedia ? parts : nil
    }
}

/// Resolves a raw path/URL string to a ``ContentPart``, or `nil` if loading fails.
private func loadMediaPart(from rawPath: String) -> ContentPart? {
    let url: URL
    if rawPath.hasPrefix("~") {
        let expanded = NSString(string: rawPath).expandingTildeInPath
        url = URL(fileURLWithPath: expanded)
    } else if rawPath.hasPrefix("/") {
        url = URL(fileURLWithPath: rawPath)
    } else {
        guard let parsed = URL(string: rawPath) else { return nil }
        url = parsed
    }

    let ext = url.pathExtension.lowercased()
    do {
        if ext == "pdf" {
            return try ContentPart.pdf(url: url)
        } else {
            return try ContentPart.image(url: url)
        }
    } catch {
        return nil
    }
}
