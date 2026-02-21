import Foundation

/// A result builder for composing tool lists with clean syntax.
///
/// Enables `if`/`else`, `for`/`in`, and comma-free tool declarations
/// inside a ``ToolGroup``:
///
/// ```swift
/// ToolGroup(name: "File System") {
///     try Tool(name: "read", description: "Read a file", input: ReadInput.self) { ... }
///     try Tool(name: "write", description: "Write a file", input: WriteInput.self) { ... }
///
///     if allowDelete {
///         try Tool(name: "delete", description: "Delete a file", input: DeleteInput.self) { ... }
///     }
/// }
/// ```
@resultBuilder
public enum ToolGroupBuilder {
    public static func buildExpression(_ tool: any ToolProvider) -> [any ToolProvider] {
        [tool]
    }

    public static func buildBlock(_ tools: [any ToolProvider]...) -> [any ToolProvider] {
        tools.flatMap(\.self)
    }

    public static func buildOptional(_ tools: [any ToolProvider]?) -> [any ToolProvider] {
        tools ?? []
    }

    public static func buildEither(first tools: [any ToolProvider]) -> [any ToolProvider] {
        tools
    }

    public static func buildEither(second tools: [any ToolProvider]) -> [any ToolProvider] {
        tools
    }

    public static func buildArray(_ tools: [[any ToolProvider]]) -> [any ToolProvider] {
        tools.flatMap(\.self)
    }
}
