import Foundation
import LLM
import MCP
@testable import Operator
import Testing

@Suite("MCP Tool Content Conversion")
struct MCPToolContentConversionTests {
    @Test("Converts single text content")
    func convertsSingleText() {
        let content: [Tool.Content] = [.text(text: "Hello, world!", annotations: nil, _meta: nil)]
        let output = ToolOutput(mcpContent: content)
        #expect(output.textContent == "Hello, world!")
        #expect(output.shouldStop == false)
    }

    @Test("Converts multiple text content items")
    func convertsMultipleText() {
        let content: [Tool.Content] = [
            .text(text: "Line one", annotations: nil, _meta: nil),
            .text(text: "Line two", annotations: nil, _meta: nil),
            .text(text: "Line three", annotations: nil, _meta: nil),
        ]
        let output = ToolOutput(mcpContent: content)
        // Each text item becomes its own ContentPart; textContent joins them
        #expect(output.content.count == 3)
        #expect(output.textContent == "Line oneLine twoLine three")
    }

    @Test("Converts image content as real ContentPart")
    func convertsImageContent() {
        let base64 = Data([0xFF, 0xD8, 0xFF, 0xE0]).base64EncodedString()
        let content: [Tool.Content] = [
            .image(data: base64, mimeType: "image/png", annotations: nil, _meta: nil),
        ]
        let output = ToolOutput(mcpContent: content)
        // Should contain a real image part, not a placeholder
        #expect(output.content.count == 1)
        if case .image = output.content[0] {
            // expected
        } else {
            Issue.record("Expected .image content part")
        }
    }

    @Test("Falls back to placeholder for invalid base64 image")
    func fallsBackForInvalidBase64() {
        let content: [Tool.Content] = [
            .image(data: "not-valid-base64!!!", mimeType: "image/png", annotations: nil, _meta: nil),
        ]
        let output = ToolOutput(mcpContent: content)
        #expect(output.textContent == "[Image: image/png]")
    }

    @Test("Converts audio content to placeholder")
    func convertsAudioContent() {
        let content: [Tool.Content] = [
            .audio(data: "base64data", mimeType: "audio/mp3", annotations: nil, _meta: nil),
        ]
        let output = ToolOutput(mcpContent: content)
        #expect(output.textContent == "[Audio: audio/mp3]")
    }

    @Test("Converts mixed content types")
    func convertsMixedContent() {
        let base64 = Data([0xFF, 0xD8]).base64EncodedString()
        let content: [Tool.Content] = [
            .text(text: "Here's the result:", annotations: nil, _meta: nil),
            .image(data: base64, mimeType: "image/jpeg", annotations: nil, _meta: nil),
            .text(text: "Done.", annotations: nil, _meta: nil),
        ]
        let output = ToolOutput(mcpContent: content)
        #expect(output.content.count == 3)
        #expect(output.textContent == "Here's the result:Done.")
    }

    @Test("Converts empty content array")
    func convertsEmptyContent() {
        let content: [Tool.Content] = []
        let output = ToolOutput(mcpContent: content)
        #expect(output.content.isEmpty)
    }

    @Test("Converts resource link content")
    func convertsResourceLinkContent() {
        let content: [Tool.Content] = [
            .resourceLink(uri: "file:///test.txt", name: "test.txt"),
        ]
        let output = ToolOutput(mcpContent: content)
        #expect(output.textContent == "[Resource: test.txt (file:///test.txt)]")
    }
}

@Suite("MCP Tool Arguments Conversion")
struct MCPToolArgumentsConversionTests {
    @Test("Converts string arguments")
    func convertsStringArguments() throws {
        let args = try ToolArguments(fromJSON: #"{"name": "Alice"}"#)
        let mcpValues: [String: MCP.Value] = try args.toMCPValues()
        #expect(mcpValues["name"] == .string("Alice"))
    }

    @Test("Converts integer arguments")
    func convertsIntegerArguments() throws {
        let args = try ToolArguments(fromJSON: #"{"count": 42}"#)
        let mcpValues: [String: MCP.Value] = try args.toMCPValues()
        #expect(mcpValues["count"] == .int(42))
    }

    @Test("Converts boolean arguments")
    func convertsBooleanArguments() throws {
        let args = try ToolArguments(fromJSON: #"{"active": true}"#)
        let mcpValues: [String: MCP.Value] = try args.toMCPValues()
        #expect(mcpValues["active"] == .bool(true))
    }

    @Test("Converts nested object arguments")
    func convertsNestedObjectArguments() throws {
        let args = try ToolArguments(fromJSON: #"{"config": {"key": "value", "count": 3}}"#)
        let mcpValues: [String: MCP.Value] = try args.toMCPValues()
        let config: MCP.Value? = mcpValues["config"]
        #expect(config?.objectValue?["key"] == .string("value"))
        #expect(config?.objectValue?["count"] == .int(3))
    }

    @Test("Converts array arguments")
    func convertsArrayArguments() throws {
        let args = try ToolArguments(fromJSON: #"{"items": ["a", "b", "c"]}"#)
        let mcpValues: [String: MCP.Value] = try args.toMCPValues()
        #expect(mcpValues["items"] == .array([.string("a"), .string("b"), .string("c")]))
    }

    @Test("Converts null arguments")
    func convertsNullArguments() throws {
        let args = try ToolArguments(fromJSON: #"{"value": null}"#)
        let mcpValues: [String: MCP.Value] = try args.toMCPValues()
        #expect(mcpValues["value"] == .null)
    }

    @Test("Converts floating point arguments")
    func convertsFloatingPointArguments() throws {
        let args = try ToolArguments(fromJSON: #"{"temperature": 0.7}"#)
        let mcpValues: [String: MCP.Value] = try args.toMCPValues()
        #expect(mcpValues["temperature"] == .double(0.7))
    }

    @Test("Converts multiple mixed arguments")
    func convertsMultipleMixedArguments() throws {
        let args = try ToolArguments(fromJSON: #"{"name": "test", "count": 5, "active": false}"#)
        let mcpValues: [String: MCP.Value] = try args.toMCPValues()
        #expect(mcpValues["name"] == .string("test"))
        #expect(mcpValues["count"] == .int(5))
        #expect(mcpValues["active"] == .bool(false))
    }

    @Test("Converts empty object")
    func convertsEmptyObject() throws {
        let args = try ToolArguments(fromJSON: #"{}"#)
        let mcpValues: [String: MCP.Value] = try args.toMCPValues()
        #expect(mcpValues.isEmpty)
    }
}
