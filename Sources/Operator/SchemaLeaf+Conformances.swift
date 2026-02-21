import Foundation
import LLM

extension URL: SchemaLeaf {
    public static var jsonSchema: LLM.OpenAICompatibleAPI.JSONSchema {
        .string()
    }

    public static var schemaPlaceholder: URL {
        URL(string: "https://placeholder.invalid")!
    }
}

extension Date: SchemaLeaf {
    public static var jsonSchema: LLM.OpenAICompatibleAPI.JSONSchema {
        .string(description: "ISO 8601 date string")
    }

    public static var schemaPlaceholder: Date {
        Date.distantPast
    }
}

extension UUID: SchemaLeaf {
    public static var jsonSchema: LLM.OpenAICompatibleAPI.JSONSchema {
        .string(description: "UUID string")
    }

    public static var schemaPlaceholder: UUID {
        UUID()
    }
}
