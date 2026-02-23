import LLM
import MCP
@testable import Operator
import Testing

@Suite("MCP Schema Conversion")
struct MCPSchemaConversionTests {
    @Test("Converts string schema")
    func convertsStringSchema() throws {
        let mcpSchema: MCP.Value = .object([
            "type": .string("string"),
            "description": .string("A name"),
        ])
        let result: LLM.OpenAICompatibleAPI.JSONSchema = try mcpSchema.toJSONSchema()
        #expect(result.type == .string)
        #expect(result.description == "A name")
    }

    @Test("Converts integer schema")
    func convertsIntegerSchema() throws {
        let mcpSchema: MCP.Value = .object([
            "type": .string("integer"),
        ])
        let result: LLM.OpenAICompatibleAPI.JSONSchema = try mcpSchema.toJSONSchema()
        #expect(result.type == .integer)
    }

    @Test("Converts number schema")
    func convertsNumberSchema() throws {
        let mcpSchema: MCP.Value = .object([
            "type": .string("number"),
        ])
        let result: LLM.OpenAICompatibleAPI.JSONSchema = try mcpSchema.toJSONSchema()
        #expect(result.type == .number)
    }

    @Test("Converts boolean schema")
    func convertsBooleanSchema() throws {
        let mcpSchema: MCP.Value = .object([
            "type": .string("boolean"),
        ])
        let result: LLM.OpenAICompatibleAPI.JSONSchema = try mcpSchema.toJSONSchema()
        #expect(result.type == .boolean)
    }

    @Test("Converts object schema with properties")
    func convertsObjectSchemaWithProperties() throws {
        let mcpSchema: MCP.Value = .object([
            "type": .string("object"),
            "properties": .object([
                "name": .object([
                    "type": .string("string"),
                    "description": .string("The user's name"),
                ]),
                "age": .object([
                    "type": .string("integer"),
                ]),
            ]),
            "required": .array([.string("name")]),
        ])
        let result: LLM.OpenAICompatibleAPI.JSONSchema = try mcpSchema.toJSONSchema()
        #expect(result.type == .object)
        #expect(result.properties?["name"]?.type == .string)
        #expect(result.properties?["name"]?.description == "The user's name")
        #expect(result.properties?["age"]?.type == .integer)
        #expect(result.required == ["name"])
    }

    @Test("Converts array schema with items")
    func convertsArraySchemaWithItems() throws {
        let mcpSchema: MCP.Value = .object([
            "type": .string("array"),
            "items": .object([
                "type": .string("string"),
            ]),
        ])
        let result: LLM.OpenAICompatibleAPI.JSONSchema = try mcpSchema.toJSONSchema()
        #expect(result.type == .array)
        #expect(result.items?.type == .string)
    }

    @Test("Converts string schema with enum values")
    func convertsStringSchemaWithEnum() throws {
        let mcpSchema: MCP.Value = .object([
            "type": .string("string"),
            "enum": .array([.string("red"), .string("green"), .string("blue")]),
        ])
        let result: LLM.OpenAICompatibleAPI.JSONSchema = try mcpSchema.toJSONSchema()
        #expect(result.type == .string)
        #expect(result.enum == ["red", "green", "blue"])
    }

    @Test("Converts nested object schema")
    func convertsNestedObjectSchema() throws {
        let mcpSchema: MCP.Value = .object([
            "type": .string("object"),
            "properties": .object([
                "address": .object([
                    "type": .string("object"),
                    "properties": .object([
                        "street": .object(["type": .string("string")]),
                        "zip": .object(["type": .string("string")]),
                    ]),
                    "required": .array([.string("street"), .string("zip")]),
                ]),
            ]),
        ])
        let result: LLM.OpenAICompatibleAPI.JSONSchema = try mcpSchema.toJSONSchema()
        #expect(result.type == .object)
        let address: LLM.OpenAICompatibleAPI.JSONSchema? = result.properties?["address"]
        #expect(address?.type == .object)
        #expect(address?.properties?["street"]?.type == .string)
        #expect(address?.properties?["zip"]?.type == .string)
        #expect(address?.required == ["street", "zip"])
    }

    @Test("Ignores unknown JSON Schema fields")
    func ignoresUnknownFields() throws {
        let mcpSchema: MCP.Value = .object([
            "type": .string("string"),
            "format": .string("email"),
            "minLength": .int(5),
            "pattern": .string("^[a-z]+$"),
        ])
        let result: LLM.OpenAICompatibleAPI.JSONSchema = try mcpSchema.toJSONSchema()
        #expect(result.type == .string)
        // These fields are silently ignored since JSONSchema has no matching properties
    }

    @Test("Converts empty object schema")
    func convertsEmptyObjectSchema() throws {
        let mcpSchema: MCP.Value = .object([
            "type": .string("object"),
        ])
        let result: LLM.OpenAICompatibleAPI.JSONSchema = try mcpSchema.toJSONSchema()
        #expect(result.type == .object)
        #expect(result.properties == nil)
        #expect(result.required == nil)
    }

    @Test("Converts array of objects")
    func convertsArrayOfObjects() throws {
        let mcpSchema: MCP.Value = .object([
            "type": .string("array"),
            "items": .object([
                "type": .string("object"),
                "properties": .object([
                    "id": .object(["type": .string("integer")]),
                    "label": .object(["type": .string("string")]),
                ]),
            ]),
        ])
        let result: LLM.OpenAICompatibleAPI.JSONSchema = try mcpSchema.toJSONSchema()
        #expect(result.type == .array)
        #expect(result.items?.type == .object)
        #expect(result.items?.properties?["id"]?.type == .integer)
        #expect(result.items?.properties?["label"]?.type == .string)
    }

    @Test("Converts schema with description only")
    func convertsSchemaWithDescriptionOnly() throws {
        let mcpSchema: MCP.Value = .object([
            "type": .string("object"),
            "description": .string("Parameters for the tool"),
            "properties": .object([:]),
        ])
        let result: LLM.OpenAICompatibleAPI.JSONSchema = try mcpSchema.toJSONSchema()
        #expect(result.type == .object)
        #expect(result.description == "Parameters for the tool")
    }
}
