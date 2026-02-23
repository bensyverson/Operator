/// An ``Operable`` that wraps all tools from a single ``MCPConnection``
/// into a ``ToolGroup``.
///
/// Created internally by ``MCPConnection/operables()`` — not intended
/// for direct construction.
struct MCPOperable: Operable {
    let toolGroup: ToolGroup
}
