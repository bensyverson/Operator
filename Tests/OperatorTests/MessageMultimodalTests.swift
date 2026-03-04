import Foundation
@testable import Operator
import Testing

@Suite("Message Multimodal")
struct MessageMultimodalTests {
    @Test("textContent joins text parts")
    func textContentJoinsTextParts() {
        let message = Message(role: .user, content: [
            .text("Hello "),
            .text("world"),
        ])
        #expect(message.textContent == "Hello world")
    }

    @Test("textContent returns nil for empty content")
    func textContentNilForEmpty() {
        let message = Message(role: .user, content: [])
        #expect(message.textContent == nil)
    }

    @Test("textContent skips non-text parts")
    func textContentSkipsMedia() {
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let message = Message(role: .user, content: [
            .text("Caption: "),
            .image(data: imageData, mediaType: "image/jpeg", filename: "photo.jpg"),
            .text("end"),
        ])
        #expect(message.textContent == "Caption: end")
    }

    @Test("hasMedia detects images")
    func hasMediaDetectsImages() {
        let imageData = Data([0xFF, 0xD8])
        let message = Message(role: .user, content: [
            .text("Look at this"),
            .image(data: imageData, mediaType: "image/jpeg"),
        ])
        #expect(message.hasMedia == true)
    }

    @Test("hasMedia false for text-only")
    func hasMediaFalseForTextOnly() {
        let message = Message(role: .user, content: [.text("Just text")])
        #expect(message.hasMedia == false)
    }

    @Test("hasMedia false for empty content")
    func hasMediaFalseForEmpty() {
        let message = Message(role: .user, content: [])
        #expect(message.hasMedia == false)
    }

    @Test("String convenience init wraps in text part")
    func stringConvenienceInit() {
        let message = Message(role: .user, content: "Hello")
        #expect(message.content.count == 1)
        #expect(message.textContent == "Hello")
    }

    @Test("Nil string convenience init produces empty content")
    func nilStringConvenienceInit() {
        let nilString: String? = nil
        let message = Message(role: .user, content: nilString)
        #expect(message.content.isEmpty)
        #expect(message.textContent == nil)
    }

    @Test("Codable round-trip with mixed content")
    func codableRoundTripMixed() throws {
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let message = Message(role: .user, content: [
            .text("Here's a photo:"),
            .image(data: imageData, mediaType: "image/jpeg", filename: "test.jpg", description: "A test image"),
        ])
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(Message.self, from: data)
        #expect(decoded == message)
        #expect(decoded.textContent == "Here's a photo:")
        #expect(decoded.hasMedia == true)
    }

    @Test("Codable round-trip with empty content")
    func codableRoundTripEmpty() throws {
        let message = Message(role: .assistant, content: [])
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(Message.self, from: data)
        #expect(decoded == message)
        #expect(decoded.content.isEmpty)
    }

    @Test("ContentPart typealias is accessible")
    func contentPartTypealiasAccessible() {
        let part: ContentPart = .text("hello")
        #expect(part.textContent == "hello")
    }
}
