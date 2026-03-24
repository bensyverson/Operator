import Foundation
import LLM
import MCP

extension ToolOutput {
    /// Creates a ``ToolOutput`` from MCP tool content.
    ///
    /// Text content becomes ``ContentPart/text(_:)`` parts. Images with valid
    /// base64 data become ``ContentPart/image(data:mediaType:filename:description:)``
    /// parts; invalid base64 falls back to a text placeholder.
    /// Non-image binary types (audio, resources) are represented as text placeholders.
    ///
    /// - Parameter content: The array of ``MCP/Tool/Content`` returned by an MCP tool call.
    init(mcpContent content: [Tool.Content]) {
        let parts: [ContentPart] = content.map { item in
            switch item {
            case let .text(text: text, annotations: _, _meta: _):
                return ContentPart.text(text)
            case let .image(data: data, mimeType: mimeType, annotations: _, _meta: _):
                if let decoded = Data(base64Encoded: data) {
                    return ContentPart.image(data: decoded, mediaType: mimeType)
                }
                return ContentPart.text("[Image: \(mimeType)]")
            case let .audio(data: _, mimeType: mimeType, annotations: _, _meta: _):
                return ContentPart.text("[Audio: \(mimeType)]")
            case let .resource(resource: resource, annotations: _, _meta: _):
                return ContentPart.text("[Resource: \(resource.uri)]")
            case let .resourceLink(uri: uri, name: name, title: _, description: _, mimeType: _, annotations: _):
                return ContentPart.text("[Resource: \(name) (\(uri))]")
            }
        }
        self.init(parts)
    }
}
