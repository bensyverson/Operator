//
//  String+ContentParts.swift
//  Chat
//
//  Parses file paths and URLs for images/PDFs from user input text,
//  returning multimodal ContentPart arrays for vision-capable models.
//

import Foundation
import Operator

/// The result of parsing a string for multimodal content.
public struct ParsedContent: Sendable {
    /// The content parts to send to the LLM (text and media interleaved).
    public let parts: [ContentPart]

    /// A human-readable version of the input with file paths replaced by
    /// labels like `[Image 1: photo.png]` or `[PDF 1: report.pdf]`.
    public let displayText: String
}

/// Supported media file extensions for multimodal content detection.
private let mediaExtensions = Set(["jpg", "jpeg", "png", "gif", "webp", "pdf"])

private let imageExtensions = Set(["jpg", "jpeg", "png", "gif", "webp"])

/// Matches absolute paths, tilde paths, and http(s) URLs ending in a media extension.
/// Path segments may contain backslash-escaped spaces (e.g. `My\ Folder`).
private nonisolated(unsafe) let mediaPattern: Regex = {
    let extensions = mediaExtensions.joined(separator: "|")
    // Each path character is either a non-whitespace/non-backslash char,
    // or a backslash followed by any character (shell escape sequence).
    return try! Regex(
        #"(?:~/|/|https?://)(?:[^\s\\]|\\.)*\.(?:"# + extensions + #")"#,
        as: Substring.self
    ).ignoresCase()
}()

public extension String {
    /// Parses the string for local file paths and remote URLs pointing to
    /// images or PDFs, returning ``ParsedContent`` with the content parts
    /// and a display-friendly version of the text.
    ///
    /// - Returns: A ``ParsedContent`` with parts and display text,
    ///   or `nil` if no media was detected or loaded.
    func contentParts() -> ParsedContent? {
        let matches = Array(matches(of: mediaPattern))
        guard !matches.isEmpty else { return nil }

        var parts = [ContentPart]()
        var displaySegments = [String]()
        var currentIndex = startIndex
        var loadedMedia = false
        var imageNumber = 0
        var pdfNumber = 0

        for match in matches {
            let matchRange = match.range

            // Add text before this match
            if currentIndex < matchRange.lowerBound {
                let text = String(self[currentIndex ..< matchRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    parts.append(.text(text))
                    displaySegments.append(text)
                }
            }

            // Try to load the media
            let rawPath = String(self[matchRange])
            let cleanPath = unescapeShellPath(rawPath)
            let filename = URL(fileURLWithPath: cleanPath).lastPathComponent
            let ext = URL(fileURLWithPath: cleanPath).pathExtension.lowercased()

            if let part = loadMediaPart(from: rawPath) {
                parts.append(part)
                loadedMedia = true

                if ext == "pdf" {
                    pdfNumber += 1
                    displaySegments.append("[PDF \(pdfNumber): \(filename)]")
                } else {
                    imageNumber += 1
                    displaySegments.append("[Image \(imageNumber): \(filename)]")
                }
            } else {
                // Loading failed — keep as text
                parts.append(.text(rawPath))
                displaySegments.append(rawPath)
            }

            currentIndex = matchRange.upperBound
        }

        // Add trailing text
        if currentIndex < endIndex {
            let text = String(self[currentIndex...])
                .trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                parts.append(.text(text))
                displaySegments.append(text)
            }
        }

        guard loadedMedia else { return nil }
        let displayText = displaySegments.joined(separator: " ")
        return ParsedContent(parts: parts, displayText: displayText)
    }
}

/// Strips shell-style backslash escapes (e.g. `\ ` → ` `, `\\` → `\`).
private func unescapeShellPath(_ path: String) -> String {
    path.replacing(#/\\(.)/#) { match in
        String(match.1)
    }
}

/// Resolves a raw path/URL string to a ``ContentPart``, or `nil` if loading fails.
private func loadMediaPart(from rawPath: String) -> ContentPart? {
    let url: URL
    if rawPath.hasPrefix("~") {
        let unescaped = unescapeShellPath(rawPath)
        let expanded = NSString(string: unescaped).expandingTildeInPath
        url = URL(fileURLWithPath: expanded)
    } else if rawPath.hasPrefix("/") {
        url = URL(fileURLWithPath: unescapeShellPath(rawPath))
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
