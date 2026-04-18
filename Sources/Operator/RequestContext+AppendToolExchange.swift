import Foundation
import LLM

public extension RequestContext {
    /// Synthesizes and appends an assistant tool-call message plus the
    /// matching tool-result message, as if the LLM had called a tool and
    /// received a response.
    ///
    /// Used by middleware — for example, a memory system — to inject
    /// recalled context proximate to the response in a cache-friendly
    /// way, rather than interleaving it with system or user messages.
    ///
    /// - Parameters:
    ///   - toolName: The tool name to cite in the synthetic call.
    ///   - arguments: An `Encodable` payload; JSON-encoded into the
    ///     call's `arguments` field.
    ///   - result: The ``ToolOutput`` that the phantom tool "returned."
    ///   - toolCallId: Optional explicit ID; generated if omitted. The
    ///     assistant message's tool call and the tool message's
    ///     ``Message/toolCallId`` are set to this value so providers see
    ///     a matched pair.
    /// - Throws: Rethrows any error from encoding `arguments`. When
    ///   encoding fails, no messages are appended.
    mutating func appendToolExchange(
        toolName: String,
        arguments: some Encodable,
        result: ToolOutput,
        toolCallId: String = UUID().uuidString
    ) throws {
        let data = try JSONEncoder().encode(arguments)
        let argumentsJSON = String(decoding: data, as: UTF8.self)

        let assistant = Message(
            role: .assistant,
            content: [],
            toolCallId: nil,
            toolCalls: [
                Message.ToolCallInfo(
                    id: toolCallId,
                    name: toolName,
                    arguments: argumentsJSON
                ),
            ]
        )

        let tool = Message(
            role: .tool,
            content: result.content,
            toolCallId: toolCallId,
            toolCalls: nil
        )

        messages.append(assistant)
        messages.append(tool)
    }
}
