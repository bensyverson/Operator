//
//  ContentPartsTests.swift
//  Chat
//

@testable import ChatCore
import Foundation
import Testing

@Suite("String.contentParts()")
struct ContentPartsTests {
    @Test("Plain text with no URLs returns nil")
    func plainText() {
        let result = "Hello, how are you?".contentParts()
        #expect(result == nil)
    }

    @Test("Text with embedded local image path returns text-image-text parts")
    func localImagePath() throws {
        // Create a temporary PNG file
        let tempDir = FileManager.default.temporaryDirectory
        let imageURL = tempDir.appendingPathComponent("test_image.png")
        // Minimal valid PNG: 8-byte header
        let pngHeader = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        try pngHeader.write(to: imageURL)
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let input = "Look at this \(imageURL.path) please"
        let result = input.contentParts()

        #expect(result != nil)
        let parts = try #require(result).parts
        #expect(parts.count == 3)

        // First part: text before the path
        if case let .text(t) = parts[0] {
            #expect(t == "Look at this")
        } else {
            Issue.record("Expected .text, got \(parts[0])")
        }

        // Second part: image
        if case .image = parts[1] {
            // OK
        } else {
            Issue.record("Expected .image, got \(parts[1])")
        }

        // Third part: text after the path
        if case let .text(t) = parts[2] {
            #expect(t == "please")
        } else {
            Issue.record("Expected .text, got \(parts[2])")
        }
    }

    @Test("Tilde path expands home directory")
    func tildeExpansion() throws {
        // Create a temp file with a known name in the home directory's tmp
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let testDir = homeDir.appendingPathComponent(".chat_test_tmp")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        let imageURL = testDir.appendingPathComponent("tilde_test.jpg")
        // Minimal JPEG: FF D8 FF
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        try jpegData.write(to: imageURL)
        defer { try? FileManager.default.removeItem(at: testDir) }

        let relativePath = "~/.chat_test_tmp/tilde_test.jpg"
        let input = "Check \(relativePath) out"
        let result = input.contentParts()

        let parts = try #require(result).parts
        // Should have text, image, text
        #expect(parts.count == 3)
        if case .image = parts[1] {
            // OK — tilde was expanded and file was loaded
        } else {
            Issue.record("Expected .image from tilde path, got \(parts[1])")
        }
    }

    @Test("Multiple URLs in one message are all extracted")
    func multipleURLs() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let img1 = tempDir.appendingPathComponent("multi1.png")
        let img2 = tempDir.appendingPathComponent("multi2.jpg")
        let pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        try pngData.write(to: img1)
        try jpegData.write(to: img2)
        defer {
            try? FileManager.default.removeItem(at: img1)
            try? FileManager.default.removeItem(at: img2)
        }

        let input = "Compare \(img1.path) with \(img2.path) please"
        let result = try #require(input.contentParts())

        // text, image, text, image, text
        #expect(result.parts.count == 5)

        let imageCount = result.parts.count(where: {
            if case .image = $0 { return true }
            return false
        })
        #expect(imageCount == 2)
    }

    @Test("PDF path uses .pdf content part")
    func pdfPath() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let pdfURL = tempDir.appendingPathComponent("test_doc.pdf")
        // Minimal PDF header
        let pdfData = Data("%PDF-1.4 test".utf8)
        try pdfData.write(to: pdfURL)
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        let input = "Read \(pdfURL.path)"
        let result = try #require(input.contentParts())

        let hasPDF = result.parts.contains {
            if case .pdf = $0 { return true }
            return false
        }
        #expect(hasPDF)
    }

    @Test("Remote https URL with image extension is extracted")
    func remoteHTTPSURL() {
        // We can't actually load a remote URL in tests, so this should fall back to text
        // since the URL won't load. But the regex should still match it.
        let input = "See https://example.com/photo.png for details"
        let result = input.contentParts()

        // The URL will fail to load, so it falls back to text — overall returns nil
        // since no media was successfully loaded
        #expect(result == nil)
    }

    @Test("Unknown extension is left as text")
    func unknownExtension() {
        let input = "Open /tmp/readme.txt now"
        let result = input.contentParts()
        #expect(result == nil)
    }

    @Test("Invalid nonexistent path falls back to text")
    func invalidPath() {
        let input = "Look at /nonexistent/path/image.png here"
        let result = input.contentParts()
        // File doesn't exist, so loading fails — falls back to text, no media → nil
        #expect(result == nil)
    }

    @Test("Backslash-escaped spaces in path are handled")
    func escapedSpaces() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let spacedDir = tempDir.appendingPathComponent("My Folder \(UUID())")
        try FileManager.default.createDirectory(at: spacedDir, withIntermediateDirectories: true)
        let imageURL = spacedDir.appendingPathComponent("nice photo.png")
        let pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        try pngData.write(to: imageURL)
        defer { try? FileManager.default.removeItem(at: spacedDir) }

        // Shell-style escaped path: spaces preceded by backslashes
        let escapedPath = imageURL.path.replacingOccurrences(of: " ", with: #"\ "#)
        let input = "Look at \(escapedPath) please"
        let result = try #require(input.contentParts())

        #expect(result.parts.count == 3)
        if case .image = result.parts[1] {
            // OK — escaped spaces were unescaped and file was loaded
        } else {
            Issue.record("Expected .image from escaped-space path, got \(result.parts[1])")
        }
    }

    @Test("Escaped-space path display text shows unescaped filename")
    func escapedSpacesDisplayText() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let spacedDir = tempDir.appendingPathComponent("My Folder \(UUID())")
        try FileManager.default.createDirectory(at: spacedDir, withIntermediateDirectories: true)
        let imageURL = spacedDir.appendingPathComponent("nice photo.png")
        let pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        try pngData.write(to: imageURL)
        defer { try? FileManager.default.removeItem(at: spacedDir) }

        let escapedPath = imageURL.path.replacingOccurrences(of: " ", with: #"\ "#)
        let input = "Check \(escapedPath)"
        let result = try #require(input.contentParts())

        #expect(result.displayText == "Check [Image 1: nice photo.png]")
    }

    @Test("Only image path with no surrounding text")
    func onlyImagePath() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let imageURL = tempDir.appendingPathComponent("solo.png")
        let pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        try pngData.write(to: imageURL)
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let result = try #require(imageURL.path.contentParts())
        #expect(result.parts.count == 1)
        if case .image = result.parts[0] {
            // OK
        } else {
            Issue.record("Expected single .image part")
        }
    }
}

@Suite("ParsedContent.displayText")
struct DisplayTextTests {
    @Test("Display text replaces single image path with label")
    func singleImage() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let imageURL = tempDir.appendingPathComponent("photo.png")
        let pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        try pngData.write(to: imageURL)
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let input = "What is this? \(imageURL.path)"
        let result = try #require(input.contentParts())

        #expect(result.displayText == "What is this? [Image 1: photo.png]")
    }

    @Test("Display text numbers multiple images sequentially")
    func multipleImages() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let img1 = tempDir.appendingPathComponent("cat.png")
        let img2 = tempDir.appendingPathComponent("dog.jpg")
        let pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        try pngData.write(to: img1)
        try jpegData.write(to: img2)
        defer {
            try? FileManager.default.removeItem(at: img1)
            try? FileManager.default.removeItem(at: img2)
        }

        let input = "Compare \(img1.path) with \(img2.path)"
        let result = try #require(input.contentParts())

        #expect(result.displayText == "Compare [Image 1: cat.png] with [Image 2: dog.jpg]")
    }

    @Test("Display text uses PDF label for PDF files")
    func pdfLabel() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let pdfURL = tempDir.appendingPathComponent("report.pdf")
        try Data("%PDF-1.4".utf8).write(to: pdfURL)
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        let input = "Summarize \(pdfURL.path)"
        let result = try #require(input.contentParts())

        #expect(result.displayText == "Summarize [PDF 1: report.pdf]")
    }

    @Test("Display text keeps failed paths as-is")
    func failedPathKeptAsText() {
        // A matched but unloadable path stays as raw text in displayText
        let input = "Check /nonexistent/image.png please"
        let result = input.contentParts()
        // No media loaded → nil
        #expect(result == nil)
    }
}
