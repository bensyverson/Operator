import Foundation
import LLM
@testable import Operator
import Testing

// MARK: - Test Input Types

private struct GreetInput: ToolInput {
    let name: String

    static var paramDescriptions: [String: String] {
        ["name": "The name to greet"]
    }
}

// MARK: - Tests

@Suite("Tool System")
struct ToolTests {
    @Test("Closure tool with ToolInput: create, call, verify output")
    func closureToolWithInput() async throws {
        let tool = try Tool(
            name: "greet",
            description: "Greet someone by name",
            input: GreetInput.self
        ) { input in
            ToolOutput("Hello, \(input.name)!")
        }

        #expect(tool.definition.function.name == "greet")
        #expect(tool.definition.function.description == "Greet someone by name")
        #expect(tool.definition.function.parameters.type == .object)
        #expect(tool.definition.function.parameters.properties?["name"]?.type == .string)

        let args = try ToolArguments(fromJSON: #"{"name": "Alice"}"#)
        let output = try await tool.call(arguments: args)
        #expect(output.content == "Hello, Alice!")
    }

    @Test("No-input tool: create, call, verify output")
    func noInputTool() async throws {
        let tool = Tool(name: "ping", description: "Return pong") {
            ToolOutput("pong")
        }

        #expect(tool.definition.function.name == "ping")
        #expect(tool.definition.function.parameters.properties?.isEmpty ?? true)

        let args = try ToolArguments(fromJSON: "{}")
        let output = try await tool.call(arguments: args)
        #expect(output.content == "pong")
    }

    @Test("Direct ToolProvider conformance (Tier 3)")
    func directToolProvider() async throws {
        struct CounterTool: ToolProvider {
            var definition: LLM.OpenAICompatibleAPI.ToolDefinition {
                LLM.OpenAICompatibleAPI.ToolDefinition(
                    function: LLM.OpenAICompatibleAPI.FunctionDefinition(
                        name: "counter",
                        description: "Return a count",
                        parameters: .object(
                            properties: ["n": .integer(description: "The number")],
                            required: ["n"]
                        )
                    )
                )
            }

            func call(arguments: ToolArguments) async throws -> ToolOutput {
                let n: Int = try arguments.require("n")
                return ToolOutput("Count: \(n)")
            }
        }

        let tool = CounterTool()
        #expect(tool.definition.function.name == "counter")

        let args = try ToolArguments(fromJSON: #"{"n": 42}"#)
        let output = try await tool.call(arguments: args)
        #expect(output.content == "Count: 42")
    }

    @Test("ToolGroup with result builder syntax")
    func toolGroupResultBuilder() {
        let group = ToolGroup(name: "Utils", description: "Utility tools") {
            Tool(name: "ping", description: "Ping") { ToolOutput("pong") }
            Tool(name: "echo", description: "Echo") { ToolOutput("echo") }
        }

        #expect(group.name == "Utils")
        #expect(group.description == "Utility tools")
        #expect(group.tools.count == 2)
        #expect(group.tools[0].definition.function.name == "ping")
        #expect(group.tools[1].definition.function.name == "echo")
    }

    @Test("ToolGroup with if/else in result builder")
    func toolGroupConditional() {
        let includeDelete = true

        let group = ToolGroup(name: "Files") {
            Tool(name: "read", description: "Read") { ToolOutput("data") }
            if includeDelete {
                Tool(name: "delete", description: "Delete") { ToolOutput("deleted") }
            }
        }

        #expect(group.tools.count == 2)

        let noDeleteGroup = ToolGroup(name: "Files") {
            Tool(name: "read", description: "Read") { ToolOutput("data") }
            if !includeDelete {
                Tool(name: "delete", description: "Delete") { ToolOutput("deleted") }
            }
        }

        #expect(noDeleteGroup.tools.count == 1)
    }

    @Test("ToolGroup with plain array init")
    func toolGroupArrayInit() {
        let tools: [any ToolProvider] = [
            Tool(name: "a", description: "A") { ToolOutput("a") },
            Tool(name: "b", description: "B") { ToolOutput("b") },
        ]

        let group = ToolGroup(name: "Test", tools: tools)
        #expect(group.tools.count == 2)
    }

    @Test("Operable conformance")
    func operableConformance() {
        struct Calculator: Operable {
            var toolGroup: ToolGroup {
                ToolGroup(name: "Calculator", description: "Math operations") {
                    Tool(name: "add", description: "Add numbers") {
                        ToolOutput("result")
                    }
                }
            }
        }

        let calc = Calculator()
        #expect(calc.toolGroup.name == "Calculator")
        #expect(calc.toolGroup.tools.count == 1)
        #expect(calc.toolGroup.tools[0].definition.function.name == "add")
    }
}
