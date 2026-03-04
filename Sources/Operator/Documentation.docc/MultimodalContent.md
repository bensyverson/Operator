# Multimodal Content

Send images, PDFs, and mixed media alongside text in conversations and tool results.

## Overview

Operator supports multimodal content through ``ContentPart``, a type aliased from the
LLM library. Messages, tool outputs, and conversations can contain any combination of
text, images, and PDFs. Models that support vision or document understanding process
the media directly; text-only models (like Apple Intelligence) receive the text content
and ignore media parts.

## Sending Multimodal Messages

Use the ``Operative/run(_:)-2uyqe`` overload that accepts `[ContentPart]`:

```swift
let imageData = try Data(contentsOf: imageURL)

let stream = operative.run([
    .text("What's in this image?"),
    .image(data: imageData, mediaType: "image/jpeg", filename: "photo.jpg"),
])

for await operation in stream {
    // Handle events as usual
}
```

You can also continue a conversation with multimodal content:

```swift
let result = try await operative.run("Hello").result()
let stream = operative.run([
    .text("Now look at this PDF:"),
    .pdf(data: pdfData, title: "report.pdf"),
], continuing: result.conversation)
```

## Multimodal Tool Results

Tools can return images and other media alongside text using ``ToolOutput``:

```swift
let screenshotTool = try Tool(
    name: "screenshot",
    description: "Takes a screenshot",
    input: ScreenshotInput.self
) { input in
    let imageData = takeScreenshot(of: input.region)
    return ToolOutput([
        .text("Screenshot captured"),
        .image(data: imageData, mediaType: "image/png", filename: "screenshot.png"),
    ])
}
```

The ``ToolOutput/textContent`` property extracts just the text portions,
while ``ToolOutput/content`` provides access to all parts including media.

## MCP Image Support

When MCP tools return image content, Operator automatically decodes
base64 image data into real ``ContentPart/image(data:mediaType:filename:description:)``
values. This means the LLM receives the actual image rather than a placeholder,
enabling vision models to analyze MCP-provided images.

## Image Resizing and Description

Configure the ``LLMServiceAdapter`` to automatically resize large images
and generate text descriptions:

```swift
let adapter = LLMServiceAdapter(provider: .anthropic(apiKey: key))

// Configure automatic image resizing (default on Apple platforms)
await adapter.setImageResizer { data, mediaType, targetSize in
    // Custom resizing logic
    return resizedData
}

// Configure automatic image description for non-vision models
await adapter.setImageDescriber { data, mediaType in
    // Generate a text description of the image
    return "A photo of a sunset over the ocean"
}
```

## Media-Aware Compaction

``CompactionMiddleware`` handles multimodal content intelligently:

- **Token estimation**: Images count as ~1000 tokens and PDFs as ~500 tokens,
  causing compaction to trigger sooner when media is present
- **Media stripping**: In older messages (before the preserve boundary), images
  and PDFs are replaced with text placeholders that preserve metadata:
  - `[Image: "sunset.jpg" — A sunset over the ocean]` (with filename and description)
  - `[Image: "photo.jpg"]` (filename only)
  - `[PDF: "report.pdf"]` (with title)

This ensures long-running sessions with many images don't exhaust the context window.

## Apple Intelligence

Apple's on-device models are text-only. When using ``AppleIntelligenceService``,
multimodal messages are handled gracefully — the ``ChatMessage/textContent``
property extracts the text portions for the on-device model, and media parts
are silently omitted.

## Content Filtering

``ContentFilter`` scans both text content and image descriptions for blocked
patterns. Image descriptions matching a blocked pattern are redacted while
preserving the image data itself.

## Topics

### Content Types
- ``ContentPart``
- ``Message``
- ``ToolOutput``

### Configuration
- ``LLMServiceAdapter/setImageResizer(_:)``
- ``LLMServiceAdapter/setImageDescriber(_:)``

### Middleware
- ``CompactionMiddleware``
- ``ContentFilter``
