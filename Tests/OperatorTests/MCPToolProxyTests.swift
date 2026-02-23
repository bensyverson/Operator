import Foundation
import LLM
import MCP
@testable import Operator
import Testing

@Suite("MCP Tool Content Conversion")
struct MCPToolContentConversionTests {
    @Test("Converts single text content")
    func convertsSingleText() {
        let content: [Tool.Content] = [.text("Hello, world!")]
        let output = ToolOutput(mcpContent: content)
        #expect(output.content == "Hello, world!")
        #expect(output.shouldStop == false)
    }

    @Test("Converts multiple text content items")
    func convertsMultipleText() {
        let content: [Tool.Content] = [
            .text("Line one"),
            .text("Line two"),
            .text("Line three"),
        ]
        let output = ToolOutput(mcpContent: content)
        #expect(output.content == "Line one\nLine two\nLine three")
    }

    @Test("Converts image content to placeholder")
    func convertsImageContent() {
        let content: [Tool.Content] = [
            .image(data: "base64data", mimeType: "image/png", metadata: nil),
        ]
        let output = ToolOutput(mcpContent: content)
        #expect(output.content == "[Image: image/png]")
    }

    @Test("Converts audio content to placeholder")
    func convertsAudioContent() {
        let content: [Tool.Content] = [
            .audio(data: "base64data", mimeType: "audio/mp3"),
        ]
        let output = ToolOutput(mcpContent: content)
        #expect(output.content == "[Audio: audio/mp3]")
    }

    @Test("Converts mixed content types")
    func convertsMixedContent() {
        let content: [Tool.Content] = [
            .text("Here's the result:"),
            .image(data: "abc", mimeType: "image/jpeg", metadata: nil),
            .text("Done."),
        ]
        let output = ToolOutput(mcpContent: content)
        #expect(output.content == "Here's the result:\n[Image: image/jpeg]\nDone.")
    }

    @Test("Converts empty content array")
    func convertsEmptyContent() {
        let content: [Tool.Content] = []
        let output = ToolOutput(mcpContent: content)
        #expect(output.content == "")
    }

    @Test("Converts resource link content")
    func convertsResourceLinkContent() {
        let content: [Tool.Content] = [
            .resourceLink(uri: "file:///test.txt", name: "test.txt"),
        ]
        let output = ToolOutput(mcpContent: content)
        #expect(output.content == "[Resource: test.txt (file:///test.txt)]")
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
