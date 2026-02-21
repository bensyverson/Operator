import Foundation
@testable import Operator
import Testing

@Suite("ToolOutput")
struct ToolOutputTests {
    @Test("Init from String")
    func initFromString() {
        let output = ToolOutput("Hello, world!")
        #expect(output.content == "Hello, world!")
        #expect(output.shouldStop == false)
    }

    @Test("Init from [String] joins with newlines")
    func initFromLines() {
        let output = ToolOutput(["line 1", "line 2", "line 3"])
        #expect(output.content == "line 1\nline 2\nline 3")
        #expect(output.shouldStop == false)
    }

    @Test("Init encoding Encodable value as JSON")
    func initEncoding() throws {
        struct TestValue: Encodable {
            let name: String
            let count: Int
        }
        let output = try ToolOutput(encoding: TestValue(name: "test", count: 42))
        // Should be valid JSON
        let parsed = try JSONSerialization.jsonObject(with: Data(output.content.utf8))
        let dict = try #require(parsed as? [String: Any])
        #expect(dict["name"] as? String == "test")
        #expect(dict["count"] as? Int == 42)
        #expect(output.shouldStop == false)
    }

    @Test("stop(reason:) sets shouldStop and stores reason")
    func stopReason() {
        let output = ToolOutput.stop(reason: "Task complete")
        #expect(output.shouldStop == true)
        #expect(output.content == "Task complete")
    }

    @Test("Default shouldStop is false")
    func defaultShouldStop() {
        let output = ToolOutput("anything")
        #expect(output.shouldStop == false)
    }

    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        let output = ToolOutput("test content")
        let data = try JSONEncoder().encode(output)
        let decoded = try JSONDecoder().decode(ToolOutput.self, from: data)
        #expect(decoded == output)
    }

    @Test("Codable round-trip for stop output")
    func codableRoundTripStop() throws {
        let output = ToolOutput.stop(reason: "done")
        let data = try JSONEncoder().encode(output)
        let decoded = try JSONDecoder().decode(ToolOutput.self, from: data)
        #expect(decoded == output)
        #expect(decoded.shouldStop == true)
    }
}
