import Foundation
import LLM

/// A type that maps to a primitive JSON Schema type but isn't a Swift primitive.
///
/// Conform to ``SchemaLeaf`` when you use a non-primitive type (like `URL`
/// or `Date`) as a tool parameter. The protocol provides two things:
///
/// - ``jsonSchema``: The JSON Schema representation of the type.
/// - ``schemaPlaceholder``: A dummy value so the schema-extracting
///   decoder can complete the type's `init(from:)`.
///
/// Primitive types (`String`, `Int`, `Double`, `Bool`) and types composed
/// of them (arrays, nested `Codable` structs) do not need this conformance.
public protocol SchemaLeaf: Codable, Sendable {
    /// The JSON Schema representation of this type.
    static var jsonSchema: JSONSchema { get }

    /// A placeholder value used during schema extraction.
    ///
    /// This value is never sent to the LLM — it exists only so the
    /// schema-extracting decoder can complete the type's `init(from:)`.
    static var schemaPlaceholder: Self { get }
}
