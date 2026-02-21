import Foundation

/// A type that provides a group of related tools to an Operative.
///
/// Conform to ``Operable`` to bundle tools with configuration state:
///
/// ```swift
/// struct FileSystem: Operable {
///     let rootPath: String
///
///     var toolGroup: ToolGroup {
///         ToolGroup(name: "File System", description: "File operations") {
///             try Tool(name: "readFile", description: "Read a file", input: ReadInput.self) { input in
///                 ToolOutput(try String(contentsOfFile: input.path, encoding: .utf8))
///             }
///         }
///     }
/// }
/// ```
///
/// The single ``toolGroup`` property avoids name collisions with
/// properties the conforming type might already have.
public protocol Operable: Sendable {
    /// The group of tools this type provides.
    var toolGroup: ToolGroup { get }
}
