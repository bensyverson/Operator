import Foundation

/// A named collection of related tools.
///
/// When the Operative builds tool schemas for the LLM, it prefixes each
/// tool's description with the group name: `[File System] Read a file`.
///
/// ``ToolGroup`` is ``Sendable`` but does not conform to ``Friendly``
/// because `[any ToolProvider]` cannot be `Codable` or `Hashable`.
///
/// ```swift
/// let group = ToolGroup(name: "Math") {
///     Tool(name: "add", description: "Add two numbers") { ... }
///     Tool(name: "multiply", description: "Multiply two numbers") { ... }
/// }
/// ```
public struct ToolGroup: Sendable {
    /// The display name for this group of tools.
    public let name: String

    /// An optional description of the group's purpose.
    public let description: String?

    /// The tools in this group.
    public let tools: [any ToolProvider]

    /// Creates a tool group from a plain array.
    public init(name: String, description: String? = nil, tools: [any ToolProvider]) {
        self.name = name
        self.description = description
        self.tools = tools
    }

    /// Creates a tool group using result builder syntax.
    public init(name: String, description: String? = nil, @ToolGroupBuilder tools: () throws -> [any ToolProvider]) rethrows {
        self.name = name
        self.description = description
        self.tools = try tools()
    }
}
