import Foundation
@testable import Operator
import Testing

@Suite("ToolArguments")
struct ToolArgumentsTests {
    @Test("Init from valid JSON string")
    func initFromValidJSON() throws {
        let args = try ToolArguments(fromJSON: #"{"name": "test", "count": 42}"#)
        #expect(args.rawData.isEmpty == false)
    }

    @Test("Init from invalid JSON throws")
    func initFromInvalidJSON() {
        #expect(throws: (any Error).self) {
            try ToolArguments(fromJSON: "not json {{{")
        }
    }

    @Test("require returns correct String value")
    func requireString() throws {
        let args = try ToolArguments(fromJSON: #"{"name": "Alice"}"#)
        let name: String = try args.require("name")
        #expect(name == "Alice")
    }

    @Test("require returns correct Int value")
    func requireInt() throws {
        let args = try ToolArguments(fromJSON: #"{"count": 42}"#)
        let count: Int = try args.require("count")
        #expect(count == 42)
    }

    @Test("require returns correct Double value")
    func requireDouble() throws {
        let args = try ToolArguments(fromJSON: #"{"price": 9.99}"#)
        let price: Double = try args.require("price")
        #expect(price == 9.99)
    }

    @Test("require returns correct Bool value")
    func requireBool() throws {
        let args = try ToolArguments(fromJSON: #"{"active": true}"#)
        let active: Bool = try args.require("active")
        #expect(active == true)
    }

    @Test("require throws for missing key")
    func requireMissingKey() throws {
        let args = try ToolArguments(fromJSON: #"{"name": "Alice"}"#)
        #expect(throws: (any Error).self) {
            let _: String = try args.require("missing")
        }
    }

    @Test("optional returns value when present")
    func optionalPresent() throws {
        let args = try ToolArguments(fromJSON: #"{"name": "Bob"}"#)
        let name: String? = args.optional("name")
        #expect(name == "Bob")
    }

    @Test("optional returns nil when missing")
    func optionalMissing() throws {
        let args = try ToolArguments(fromJSON: #"{"name": "Bob"}"#)
        let age: Int? = args.optional("age")
        #expect(age == nil)
    }

    @Test("rawData returns the stored bytes")
    func rawDataProperty() throws {
        let json = #"{"key": "value"}"#
        let args = try ToolArguments(fromJSON: json)
        #expect(args.rawData.isEmpty == false)
        // rawData should be valid JSON
        let parsed = try JSONSerialization.jsonObject(with: args.rawData)
        let dict = try #require(parsed as? [String: Any])
        #expect(dict["key"] as? String == "value")
    }

    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        let args = try ToolArguments(fromJSON: #"{"name": "test", "count": 42}"#)
        let data = try JSONEncoder().encode(args)
        let decoded = try JSONDecoder().decode(ToolArguments.self, from: data)
        #expect(decoded == args)
        // Verify we can still read values after decoding
        let name: String = try decoded.require("name")
        #expect(name == "test")
    }

    @Test("Nested object decoding via require")
    func nestedObject() throws {
        let json = #"{"user": {"name": "Alice", "age": 30}}"#
        let args = try ToolArguments(fromJSON: json)

        struct User: Decodable, Equatable {
            let name: String
            let age: Int
        }

        let user: User = try args.require("user")
        #expect(user.name == "Alice")
        #expect(user.age == 30)
    }
}
