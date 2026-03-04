import Foundation
@testable import Operator
import Testing

@Suite("ToolOutput Multimodal")
struct ToolOutputMultimodalTests {
    @Test("Init from [ContentPart] with mixed content")
    func initFromParts() {
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let output = ToolOutput([
            .text("Here's the screenshot:"),
            .image(data: imageData, mediaType: "image/jpeg", filename: "screen.jpg"),
        ])
        #expect(output.textContent == "Here's the screenshot:")
        #expect(output.content.count == 2)
        #expect(output.shouldStop == false)
    }

    @Test("textContent joins text parts")
    func textContentJoins() {
        let output = ToolOutput([.text("Hello "), .text("world")])
        #expect(output.textContent == "Hello world")
    }

    @Test("textContent returns nil for media-only")
    func textContentNilForMediaOnly() {
        let imageData = Data([0xFF, 0xD8])
        let output = ToolOutput([.image(data: imageData, mediaType: "image/png")])
        #expect(output.textContent == nil)
    }

    @Test("String init wraps in text part")
    func stringInitWraps() {
        let output = ToolOutput("Hello")
        #expect(output.content.count == 1)
        #expect(output.textContent == "Hello")
    }

    @Test("Lines init joins and wraps in text part")
    func linesInitJoins() {
        let output = ToolOutput(["a", "b", "c"])
        #expect(output.content.count == 1)
        #expect(output.textContent == "a\nb\nc")
    }

    @Test("Codable round-trip with multimodal content")
    func codableRoundTrip() throws {
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let output = ToolOutput([
            .text("Result:"),
            .image(data: imageData, mediaType: "image/jpeg"),
        ])
        let data = try JSONEncoder().encode(output)
        let decoded = try JSONDecoder().decode(ToolOutput.self, from: data)
        #expect(decoded == output)
        #expect(decoded.textContent == "Result:")
    }

    @Test("stop(reason:) remains text-only")
    func stopIsTextOnly() {
        let output = ToolOutput.stop(reason: "Done")
        #expect(output.content.count == 1)
        #expect(output.textContent == "Done")
        #expect(output.shouldStop == true)
    }
}
