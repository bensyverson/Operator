# ToolInput and Schema Extraction

Defining tool parameters with plain Codable structs.

## Overview

``ToolInput`` is the mechanism that lets you define a tool's parameters as a plain Swift struct. Instead of manually building a ``JSONSchema``, you write a `Codable` type with a descriptions dictionary, and Operator derives the full parameter schema automatically.

This works through a **schema-extracting decoder** — a custom `Decoder` that introspects a type's `Codable` implementation to discover its property names, types, and optionality, then combines that information with your descriptions to produce a complete ``JSONSchema``.

## Defining a ToolInput

A ``ToolInput`` is a `Codable & Sendable` struct with a static ``paramDescriptions`` dictionary:

```swift
struct ParseURLInput: ToolInput {
    let url: URL
    let components: [URLComponent]
    let maxResults: Int?

    static var paramDescriptions: [String: String] {
        [
            "url": "The URL to parse",
            "components": "Which URL components to extract",
            "maxResults": "Maximum number of results to return",
        ]
    }
}
```

That's the entire definition. From this, Operator extracts:

| Property | Source | Value |
|----------|--------|-------|
| Parameter names | `Codable` (auto-synthesized `CodingKeys`) | `"url"`, `"components"`, `"maxResults"` |
| JSON types | `Codable` decode calls + `SchemaLeaf` | `string`, `array`, `integer` |
| Required vs optional | `Optional<T>` vs `T` | `url` and `components` required; `maxResults` optional |
| Descriptions | `paramDescriptions` dictionary | As provided |
| Enum constraints | `CaseIterable` conformance on value types | Automatic for enum types |

The generated JSON Schema:

```json
{
    "type": "object",
    "properties": {
        "url": {
            "type": "string",
            "description": "The URL to parse"
        },
        "components": {
            "type": "array",
            "items": {
                "type": "string",
                "enum": ["scheme", "host", "port", "path", "query", "fragment"]
            },
            "description": "Which URL components to extract"
        },
        "maxResults": {
            "type": "integer",
            "description": "Maximum number of results to return"
        }
    },
    "required": ["url", "components"]
}
```

## The ToolInput Protocol

```swift
protocol ToolInput: Codable & Sendable {
    /// Human-readable descriptions for each parameter, keyed by property name.
    static var paramDescriptions: [String: String] { get }
}
```

That's the entire protocol. The schema extraction, JSON decoding, and validation are handled by Operator's infrastructure — no additional methods to implement.

## How Schema Extraction Works

When a ``ToolProvider`` is registered with a ``ToolInput`` type, Operator runs the schema-extracting decoder once at registration time:

1. **Invoke the type's `init(from:)`** using a custom `Decoder` implementation. This doesn't decode real data — it intercepts the calls the synthesized initializer makes.

2. **Record property metadata** from the custom `KeyedDecodingContainer`. When the synthesized `init(from:)` calls `container.decode(URL.self, forKey: someKey)`, the container records:
   - The property name: `someKey.stringValue` → `"url"`
   - Whether it was `decode` (required) or `decodeIfPresent` (optional)
   - The type being decoded: `URL.self`

3. **Resolve JSON Schema types** by examining decode calls:
   - Primitive types (`String`, `Int`, `Double`, `Bool`) are detected via the concrete overloads on `KeyedDecodingContainer` and map directly to JSON Schema types.
   - Non-primitive types (like `URL`) hit the generic `decode<T: Decodable>` path. The decoder recursively decodes `T` to discover its underlying representation. For example, `URL`'s `init(from:)` calls `singleValueContainer().decode(String.self)`, revealing that URLs are represented as strings.
   - Array types trigger an `unkeyedContainer`, and the decoder inspects the element type to build an `array(items:)` schema.
   - Nested object types trigger a `container(keyedBy:)`, producing a nested `object(properties:)` schema.

4. **Apply descriptions** from ``paramDescriptions`` to the corresponding properties.

5. **Extract enum constraints** for types conforming to `CaseIterable`, automatically populating the `enum` field in the JSON Schema.

6. **Validate** that every key in ``paramDescriptions`` matches an actual property. Mismatched keys (likely typos) produce a diagnostic error at registration time, not at runtime.

### Dummy Values

The decoder needs to return values from `decode` calls so the type's `init(from:)` can complete. For primitive types, it returns defaults (`""`, `0`, `false`, `0.0`). For optional properties, `decodeIfPresent` returns `nil`. For non-primitive types like `URL` or `Date`, the ``SchemaLeaf`` protocol provides a placeholder value.

## SchemaLeaf

``SchemaLeaf`` is a small protocol for types that are represented as primitives in JSON but aren't primitive Swift types. It provides two things: the JSON Schema mapping and a placeholder value for the schema extractor.

```swift
protocol SchemaLeaf: Codable & Sendable {
    /// The JSON Schema representation of this type.
    static var jsonSchema: JSONSchema { get }

    /// A placeholder value used during schema extraction.
    /// This value is never sent to the LLM — it exists only so the
    /// schema-extracting decoder can complete the type's init(from:).
    static var schemaPlaceholder: Self { get }
}
```

Operator ships conformances for common types:

```swift
extension URL: SchemaLeaf {
    static var jsonSchema: JSONSchema { .string() }
    static var schemaPlaceholder: URL { URL(string: "https://placeholder.invalid")! }
}

extension Date: SchemaLeaf {
    static var jsonSchema: JSONSchema { .string(description: "ISO 8601 date string") }
    static var schemaPlaceholder: Date { Date.distantPast }
}

extension UUID: SchemaLeaf {
    static var jsonSchema: JSONSchema { .string(description: "UUID string") }
    static var schemaPlaceholder: UUID { UUID() }
}
```

You only need to conform to ``SchemaLeaf`` if you use a non-primitive type as a tool parameter and it isn't already covered by the shipped conformances. Primitive types (`String`, `Int`, `Double`, `Bool`) and types composed of them (arrays, nested `Codable` structs) do not need ``SchemaLeaf`` conformance.

## Enums as Parameters

Swift enums with `String` raw values that conform to `CaseIterable` are particularly powerful as tool parameters. The schema extractor automatically generates `enum` constraints:

```swift
enum URLComponent: String, Codable, Sendable, CaseIterable {
    case scheme, host, port, path, query, fragment

    func extract(from url: URL) -> String {
        switch self {
        case .scheme:   url.scheme ?? "nil"
        case .host:     url.host ?? "nil"
        case .port:     url.port.map(String.init) ?? "nil"
        case .path:     url.path
        case .query:    url.query ?? "nil"
        case .fragment: url.fragment ?? "nil"
        }
    }
}
```

When used in a ``ToolInput``, `Param<[URLComponent]>` generates:

```json
{
    "type": "array",
    "items": {
        "type": "string",
        "enum": ["scheme", "host", "port", "path", "query", "fragment"]
    }
}
```

The LLM sees the allowed values and is constrained to them. When the response comes back, Operator decodes directly into `[URLComponent]` — fully typed, fully validated.

## Nested Object Parameters

For tools with structured inputs, use nested `Codable` types:

```swift
struct Coordinate: Codable, Sendable {
    let latitude: Double
    let longitude: Double
}

struct GeoSearchInput: ToolInput {
    let center: Coordinate
    let radiusKm: Double
    let query: String

    static var paramDescriptions: [String: String] {
        [
            "center": "The center point for the search",
            "radiusKm": "Search radius in kilometers",
            "query": "What to search for",
        ]
    }
}
```

The schema extractor recurses into `Coordinate` to produce:

```json
{
    "type": "object",
    "properties": {
        "center": {
            "type": "object",
            "properties": {
                "latitude": { "type": "number" },
                "longitude": { "type": "number" }
            },
            "required": ["latitude", "longitude"],
            "description": "The center point for the search"
        },
        "radiusKm": { "type": "number", "description": "Search radius in kilometers" },
        "query": { "type": "string", "description": "What to search for" }
    },
    "required": ["center", "radiusKm", "query"]
}
```

Nested types don't need their own ``paramDescriptions`` — they're described by the parent's description for that property. If you need per-field descriptions on nested types, conform them to ``ToolInput`` as well.

## Testing ToolInput Types

Because ``ToolInput`` types are plain `Codable` structs, they're easy to construct in tests:

```swift
@Test func parseURLInput() async throws {
    let input = ParseURLInput(
        url: URL(string: "https://example.com:8080/path")!,
        components: [.host, .port],
        maxResults: nil
    )

    #expect(input.url.host == "example.com")
    #expect(input.components.count == 2)
}
```

No JSON dictionaries, no `ToolArguments` — just normal struct construction. This makes it easy to test tool logic independently of the schema extraction and LLM integration.

## Topics

### Related

- <doc:ToolsAndOperables>
