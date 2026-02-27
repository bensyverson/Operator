import Foundation
@testable import Operator
import Testing

@Suite("ClosureTool Decoding Error Tests")
struct ClosureToolDecodingTests {
    struct WriteInput: ToolInput {
        let path: String
        let content: String

        static var paramDescriptions: [String: String] {
            [
                "path": "The file path to write to",
                "content": "The content to write",
            ]
        }
    }

    let writeTool: any ToolProvider = try! Tool(
        name: "write_file",
        description: "Create a new file with the given path and content.",
        input: WriteInput.self
    ) { input in
        ToolOutput("Wrote \(input.content.count) bytes to \(input.path)")
    }

    @Test("Missing required parameter names the key and lists expected params")
    func missingRequiredParameter() async throws {
        let args = try ToolArguments(fromJSON: #"{"path": "/tmp/test.txt"}"#)
        do {
            _ = try await writeTool.call(arguments: args)
            Issue.record("Expected ToolError to be thrown")
        } catch let error as ToolError {
            #expect(error.message.contains("content"))
            #expect(error.message.contains("write_file expects:"))
            #expect(error.message.contains("path (string, required)"))
            #expect(error.message.contains("content (string, required)"))
        }
    }

    @Test("Empty object for tool with required params lists all of them")
    func emptyObjectListsAllParams() async throws {
        let args = try ToolArguments(fromJSON: #"{}"#)
        do {
            _ = try await writeTool.call(arguments: args)
            Issue.record("Expected ToolError to be thrown")
        } catch let error as ToolError {
            #expect(error.message.contains("write_file expects:"))
            #expect(error.message.contains("path (string, required)"))
            #expect(error.message.contains("content (string, required)"))
        }
    }

    @Test("Wrong type produces message naming expected type")
    func wrongTypeParameter() async throws {
        let args = try ToolArguments(fromJSON: #"{"path": 42, "content": "hello"}"#)
        do {
            _ = try await writeTool.call(arguments: args)
            Issue.record("Expected ToolError to be thrown")
        } catch let error as ToolError {
            #expect(error.message.contains("path"))
            #expect(error.message.contains("write_file expects:"))
        }
    }

    @Test("Valid args decode successfully without error")
    func validArgsNoRegression() async throws {
        let args = try ToolArguments(fromJSON: #"{"path": "/tmp/test.txt", "content": "hello world"}"#)
        let output = try await writeTool.call(arguments: args)
        #expect(output.content.contains("11 bytes"))
        #expect(output.content.contains("/tmp/test.txt"))
    }

    @Test("ToolError.localizedDescription returns the message")
    func toolErrorLocalizedDescription() {
        let error = ToolError(
            message: "Something went wrong",
            underlyingError: NSError(domain: "test", code: 0)
        )
        #expect(error.localizedDescription == "Something went wrong")
    }
}
