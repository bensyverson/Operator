import Foundation
import LLM

extension URL: SchemaLeaf {
    /// The JSON schema representation for URL values.
    public static var jsonSchema: JSONSchema {
        .string()
    }

    /// A placeholder URL used during schema extraction.
    public static var schemaPlaceholder: URL {
        URL(string: "https://placeholder.invalid")!
    }
}

extension Date: SchemaLeaf {
    /// The JSON schema representation for Date values.
    public static var jsonSchema: JSONSchema {
        .string(description: "ISO 8601 date string")
    }

    /// A placeholder Date used during schema extraction.
    public static var schemaPlaceholder: Date {
        Date.distantPast
    }
}

extension UUID: SchemaLeaf {
    /// The JSON schema representation for UUID values.
    public static var jsonSchema: JSONSchema {
        .string(description: "UUID string")
    }

    /// A placeholder UUID used during schema extraction.
    public static var schemaPlaceholder: UUID {
        UUID()
    }
}
