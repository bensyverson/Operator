import Foundation
import LLM
@testable import Operator
import Testing

// MARK: - Test Input Types

private struct PrimitivesInput: ToolInput {
    let name: String
    let age: Int
    let score: Double
    let active: Bool

    static var paramDescriptions: [String: String] {
        ["name": "The name", "age": "The age", "score": "The score", "active": "Is active"]
    }
}

private struct OptionalInput: ToolInput {
    let required: String
    let optional: String?

    static var paramDescriptions: [String: String] {
        ["required": "Required field", "optional": "Optional field"]
    }
}

private struct ArrayInput: ToolInput {
    let tags: [String]

    static var paramDescriptions: [String: String] {
        ["tags": "List of tags"]
    }
}

private enum Color: String, Codable, CaseIterable, Sendable {
    case red, green, blue
}

private struct EnumInput: ToolInput {
    let color: Color

    static var paramDescriptions: [String: String] {
        ["color": "The color"]
    }
}

private struct EnumArrayInput: ToolInput {
    let colors: [Color]

    static var paramDescriptions: [String: String] {
        ["colors": "The colors"]
    }
}

private struct URLInput: ToolInput {
    let url: URL

    static var paramDescriptions: [String: String] {
        ["url": "The URL"]
    }
}

private struct Inner: Codable, Sendable {
    let x: Int
    let y: Int
}

private struct NestedInput: ToolInput {
    let point: Inner

    static var paramDescriptions: [String: String] {
        ["point": "A coordinate point"]
    }
}

private struct BadDescriptionsInput: ToolInput {
    let name: String

    static var paramDescriptions: [String: String] {
        ["naem": "Typo!"]
    }
}

private struct EmptyInput: ToolInput {
    static var paramDescriptions: [String: String] {
        [:]
    }
}

private struct DescribedInput: ToolInput {
    let query: String
    let count: Int

    static var paramDescriptions: [String: String] {
        ["query": "The search query", "count": "Number of results"]
    }
}

// MARK: - Tests

@Suite("SchemaExtractingDecoder")
struct SchemaExtractingDecoderTests {
    typealias JSONSchema = LLM.OpenAICompatibleAPI.JSONSchema

    @Test("Extracts primitives: String, Int, Double, Bool")
    func primitives() throws {
        let schema = try SchemaExtractingDecoder.extractSchema(from: PrimitivesInput.self)

        #expect(schema.type == .object)
        #expect(schema.properties?["name"]?.type == .string)
        #expect(schema.properties?["age"]?.type == .integer)
        #expect(schema.properties?["score"]?.type == .number)
        #expect(schema.properties?["active"]?.type == .boolean)

        let required = schema.required ?? []
        #expect(required.contains("name"))
        #expect(required.contains("age"))
        #expect(required.contains("score"))
        #expect(required.contains("active"))
    }

    @Test("Distinguishes required from optional properties")
    func optionals() throws {
        let schema = try SchemaExtractingDecoder.extractSchema(from: OptionalInput.self)

        #expect(schema.properties?["required"]?.type == .string)
        #expect(schema.properties?["optional"]?.type == .string)

        let required = schema.required ?? []
        #expect(required.contains("required"))
        #expect(!required.contains("optional"))
    }

    @Test("Extracts array of strings")
    func arrays() throws {
        let schema = try SchemaExtractingDecoder.extractSchema(from: ArrayInput.self)

        let tagsSchema = schema.properties?["tags"]
        #expect(tagsSchema?.type == .array)
        #expect(tagsSchema?.items?.type == .string)
    }

    @Test("Extracts CaseIterable enum as string with enum values")
    func caseIterableEnum() throws {
        let schema = try SchemaExtractingDecoder.extractSchema(from: EnumInput.self)

        let colorSchema = schema.properties?["color"]
        #expect(colorSchema?.type == .string)
        #expect(colorSchema?.enum == ["red", "green", "blue"])
    }

    @Test("Extracts array of CaseIterable enums")
    func enumArray() throws {
        let schema = try SchemaExtractingDecoder.extractSchema(from: EnumArrayInput.self)

        let colorsSchema = schema.properties?["colors"]
        #expect(colorsSchema?.type == .array)
        #expect(colorsSchema?.items?.type == .string)
        #expect(colorsSchema?.items?.enum == ["red", "green", "blue"])
    }

    @Test("Extracts SchemaLeaf type (URL)")
    func schemaLeaf() throws {
        let schema = try SchemaExtractingDecoder.extractSchema(from: URLInput.self)

        let urlSchema = schema.properties?["url"]
        #expect(urlSchema?.type == .string)
    }

    @Test("Extracts nested struct as nested object")
    func nestedStruct() throws {
        let schema = try SchemaExtractingDecoder.extractSchema(from: NestedInput.self)

        let pointSchema = schema.properties?["point"]
        #expect(pointSchema?.type == .object)
        #expect(pointSchema?.properties?["x"]?.type == .integer)
        #expect(pointSchema?.properties?["y"]?.type == .integer)

        let innerRequired = pointSchema?.required ?? []
        #expect(innerRequired.contains("x"))
        #expect(innerRequired.contains("y"))
    }

    @Test("Throws on mismatched paramDescriptions key")
    func descriptionValidation() throws {
        #expect(throws: SchemaExtractionError.self) {
            try SchemaExtractingDecoder.extractSchema(from: BadDescriptionsInput.self)
        }
    }

    @Test("Handles empty struct")
    func emptyStruct() throws {
        let schema = try SchemaExtractingDecoder.extractSchema(from: EmptyInput.self)

        #expect(schema.type == .object)
        #expect(schema.properties?.isEmpty ?? true)
    }

    @Test("Applies paramDescriptions as property descriptions")
    func descriptionsApplied() throws {
        let schema = try SchemaExtractingDecoder.extractSchema(from: DescribedInput.self)

        #expect(schema.properties?["query"]?.description == "The search query")
        #expect(schema.properties?["count"]?.description == "Number of results")
    }
}
