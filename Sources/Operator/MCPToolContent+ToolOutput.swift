import MCP

extension ToolOutput {
    /// Creates a ``ToolOutput`` from MCP tool content.
    ///
    /// Text content is included directly. Non-text types (images, audio,
    /// resources) are represented as descriptive placeholders. Multiple
    /// content items are joined with newlines.
    ///
    /// - Parameter content: The array of ``MCP/Tool/Content`` returned by an MCP tool call.
    init(mcpContent content: [Tool.Content]) {
        let lines: [String] = content.map { item in
            switch item {
            case let .text(text):
                text
            case let .image(_, mimeType, _):
                "[Image: \(mimeType)]"
            case let .audio(_, mimeType):
                "[Audio: \(mimeType)]"
            case let .resource(resource, _, _):
                "[Resource: \(resource.uri)]"
            case let .resourceLink(uri, name, _, _, _, _):
                "[Resource: \(name) (\(uri))]"
            }
        }
        self.init(lines)
    }
}
