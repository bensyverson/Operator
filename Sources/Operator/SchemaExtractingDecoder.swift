import Foundation
import LLM

/// Errors thrown during schema extraction.
public enum SchemaExtractionError: Error, LocalizedError {
    /// A key in ``ToolInput/paramDescriptions`` does not match any property.
    case unknownDescriptionKeys([String], knownProperties: [String])

    public var errorDescription: String? {
        switch self {
        case let .unknownDescriptionKeys(keys, knownProperties):
            let keyList = keys.joined(separator: ", ")
            let propList = knownProperties.joined(separator: ", ")
            return "paramDescriptions contains keys that don't match any property: [\(keyList)]. Known properties: [\(propList)]"
        }
    }
}

/// Extracts a JSON Schema from a ``ToolInput`` type by intercepting its
/// synthesized `init(from:)` calls.
///
/// This is a namespace enum — use ``extractSchema(from:)`` to invoke.
public enum SchemaExtractingDecoder {
    /// Extracts a JSON Schema from a ``ToolInput`` type.
    ///
    /// Invokes the type's `init(from:)` with a custom `Decoder` that
    /// records property names, types, and optionality, then maps them
    /// to a ``JSONSchema``.
    ///
    /// - Parameter type: The ``ToolInput`` type to extract a schema from.
    /// - Returns: A ``JSONSchema`` representing the type's parameters.
    /// - Throws: ``SchemaExtractionError`` if ``ToolInput/paramDescriptions``
    ///   contains keys that don't match any property.
    public static func extractSchema<T: ToolInput>(from type: T.Type) throws -> JSONSchema {
        let decoder = DecoderImpl()
        _ = try T(from: decoder)

        guard let recorder = decoder.propertyRecorder else {
            // Type decoded via single value or unkeyed — treat as empty object
            return JSONSchema.object(properties: [:])
        }

        // Validate paramDescriptions keys
        let propertyNames = Set(recorder.properties.map(\.name))
        let descriptionKeys = Set(type.paramDescriptions.keys)
        let unknownKeys = descriptionKeys.subtracting(propertyNames)
        if !unknownKeys.isEmpty {
            throw SchemaExtractionError.unknownDescriptionKeys(
                unknownKeys.sorted(),
                knownProperties: propertyNames.sorted()
            )
        }

        // Build properties dict and required list
        var properties: [String: JSONSchema] = [:]
        var required: [String] = []

        for prop in recorder.properties {
            var schema = prop.schema
            if let description = type.paramDescriptions[prop.name] {
                schema = schema.withDescription(description)
            }
            properties[prop.name] = schema
            if prop.isRequired {
                required.append(prop.name)
            }
        }

        return JSONSchema.object(
            properties: properties,
            required: required.isEmpty ? nil : required
        )
    }
}

// MARK: - Internal Types

extension SchemaExtractingDecoder {
    struct RecordedProperty {
        let name: String
        let schema: JSONSchema
        let isRequired: Bool
    }

    /// Shared storage for recorded properties, allowing the decoder
    /// to read properties recorded by a generic `KeyedContainerImpl<Key>`.
    final class PropertyRecorder {
        var properties: [RecordedProperty] = []
    }

    struct AnyCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init(stringValue: String) {
            self.stringValue = stringValue
            intValue = nil
        }

        init(intValue: Int) {
            stringValue = "\(intValue)"
            self.intValue = intValue
        }
    }
}

// MARK: - DecoderImpl

extension SchemaExtractingDecoder {
    final class DecoderImpl: Decoder {
        var codingPath: [CodingKey] = []
        var userInfo: [CodingUserInfoKey: Any] = [:]
        var propertyRecorder: PropertyRecorder?
        var unkeyedContainerImpl: UnkeyedContainerImpl?
        var singleValueContainerImpl: SingleValueContainerImpl?

        func container<Key: CodingKey>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> {
            let recorder = PropertyRecorder()
            propertyRecorder = recorder
            let impl = KeyedContainerImpl<Key>(codingPath: codingPath, recorder: recorder)
            return KeyedDecodingContainer(impl)
        }

        func unkeyedContainer() throws -> UnkeyedDecodingContainer {
            let impl = UnkeyedContainerImpl(codingPath: codingPath)
            unkeyedContainerImpl = impl
            return impl
        }

        func singleValueContainer() throws -> SingleValueDecodingContainer {
            let impl = SingleValueContainerImpl(codingPath: codingPath)
            singleValueContainerImpl = impl
            return impl
        }
    }
}

// MARK: - KeyedContainerImpl

extension SchemaExtractingDecoder {
    final class KeyedContainerImpl<Key: CodingKey>: KeyedDecodingContainerProtocol {
        var codingPath: [CodingKey]
        var allKeys: [Key] = []
        let recorder: PropertyRecorder

        init(codingPath: [CodingKey], recorder: PropertyRecorder) {
            self.codingPath = codingPath
            self.recorder = recorder
        }

        func contains(_: Key) -> Bool {
            true
        }

        func decodeNil(forKey _: Key) throws -> Bool {
            true
        }

        // MARK: Primitive decode

        func decode(_: Bool.Type, forKey key: Key) throws -> Bool {
            record(key: key, schema: .boolean(), isRequired: true); return false
        }

        func decode(_: String.Type, forKey key: Key) throws -> String {
            record(key: key, schema: .string(), isRequired: true); return ""
        }

        func decode(_: Double.Type, forKey key: Key) throws -> Double {
            record(key: key, schema: .number(), isRequired: true); return 0.0
        }

        func decode(_: Float.Type, forKey key: Key) throws -> Float {
            record(key: key, schema: .number(), isRequired: true); return 0.0
        }

        func decode(_: Int.Type, forKey key: Key) throws -> Int {
            record(key: key, schema: .integer(), isRequired: true); return 0
        }

        func decode(_: Int8.Type, forKey key: Key) throws -> Int8 {
            record(key: key, schema: .integer(), isRequired: true); return 0
        }

        func decode(_: Int16.Type, forKey key: Key) throws -> Int16 {
            record(key: key, schema: .integer(), isRequired: true); return 0
        }

        func decode(_: Int32.Type, forKey key: Key) throws -> Int32 {
            record(key: key, schema: .integer(), isRequired: true); return 0
        }

        func decode(_: Int64.Type, forKey key: Key) throws -> Int64 {
            record(key: key, schema: .integer(), isRequired: true); return 0
        }

        func decode(_: UInt.Type, forKey key: Key) throws -> UInt {
            record(key: key, schema: .integer(), isRequired: true); return 0
        }

        func decode(_: UInt8.Type, forKey key: Key) throws -> UInt8 {
            record(key: key, schema: .integer(), isRequired: true); return 0
        }

        func decode(_: UInt16.Type, forKey key: Key) throws -> UInt16 {
            record(key: key, schema: .integer(), isRequired: true); return 0
        }

        func decode(_: UInt32.Type, forKey key: Key) throws -> UInt32 {
            record(key: key, schema: .integer(), isRequired: true); return 0
        }

        func decode(_: UInt64.Type, forKey key: Key) throws -> UInt64 {
            record(key: key, schema: .integer(), isRequired: true); return 0
        }

        // MARK: Generic decode

        func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
            let (schema, value) = try resolveType(type)
            record(key: key, schema: schema, isRequired: true)
            return value
        }

        // MARK: decodeIfPresent — primitives

        func decodeIfPresent(_: Bool.Type, forKey key: Key) throws -> Bool? {
            record(key: key, schema: .boolean(), isRequired: false); return nil
        }

        func decodeIfPresent(_: String.Type, forKey key: Key) throws -> String? {
            record(key: key, schema: .string(), isRequired: false); return nil
        }

        func decodeIfPresent(_: Double.Type, forKey key: Key) throws -> Double? {
            record(key: key, schema: .number(), isRequired: false); return nil
        }

        func decodeIfPresent(_: Float.Type, forKey key: Key) throws -> Float? {
            record(key: key, schema: .number(), isRequired: false); return nil
        }

        func decodeIfPresent(_: Int.Type, forKey key: Key) throws -> Int? {
            record(key: key, schema: .integer(), isRequired: false); return nil
        }

        func decodeIfPresent(_: Int8.Type, forKey key: Key) throws -> Int8? {
            record(key: key, schema: .integer(), isRequired: false); return nil
        }

        func decodeIfPresent(_: Int16.Type, forKey key: Key) throws -> Int16? {
            record(key: key, schema: .integer(), isRequired: false); return nil
        }

        func decodeIfPresent(_: Int32.Type, forKey key: Key) throws -> Int32? {
            record(key: key, schema: .integer(), isRequired: false); return nil
        }

        func decodeIfPresent(_: Int64.Type, forKey key: Key) throws -> Int64? {
            record(key: key, schema: .integer(), isRequired: false); return nil
        }

        func decodeIfPresent(_: UInt.Type, forKey key: Key) throws -> UInt? {
            record(key: key, schema: .integer(), isRequired: false); return nil
        }

        func decodeIfPresent(_: UInt8.Type, forKey key: Key) throws -> UInt8? {
            record(key: key, schema: .integer(), isRequired: false); return nil
        }

        func decodeIfPresent(_: UInt16.Type, forKey key: Key) throws -> UInt16? {
            record(key: key, schema: .integer(), isRequired: false); return nil
        }

        func decodeIfPresent(_: UInt32.Type, forKey key: Key) throws -> UInt32? {
            record(key: key, schema: .integer(), isRequired: false); return nil
        }

        func decodeIfPresent(_: UInt64.Type, forKey key: Key) throws -> UInt64? {
            record(key: key, schema: .integer(), isRequired: false); return nil
        }

        func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
            let (schema, _) = try resolveType(type)
            record(key: key, schema: schema, isRequired: false)
            return nil
        }

        // MARK: Nested containers

        func nestedContainer<NestedKey: CodingKey>(
            keyedBy _: NestedKey.Type,
            forKey key: Key
        ) throws -> KeyedDecodingContainer<NestedKey> {
            KeyedDecodingContainer(KeyedContainerImpl<NestedKey>(
                codingPath: codingPath + [key],
                recorder: PropertyRecorder()
            ))
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            UnkeyedContainerImpl(codingPath: codingPath + [key])
        }

        func superDecoder() throws -> Decoder {
            DecoderImpl()
        }

        func superDecoder(forKey _: Key) throws -> Decoder {
            DecoderImpl()
        }

        // MARK: Helpers

        private func record(key: Key, schema: JSONSchema, isRequired: Bool) {
            recorder.properties.append(RecordedProperty(
                name: key.stringValue,
                schema: schema,
                isRequired: isRequired
            ))
        }

        /// Resolves a generic Decodable type to its JSON Schema and a dummy value.
        private func resolveType<T: Decodable>(_ type: T.Type) throws -> (JSONSchema, T) {
            // 1. SchemaLeaf
            if let leafType = type as? any SchemaLeaf.Type {
                let schema = leafType.jsonSchema
                let placeholder = leafType.schemaPlaceholder
                return (schema, placeholder as! T)
            }

            // 2. CaseIterable enum
            if let enumSchema = extractEnumSchema(type) {
                let allCases = (type as! any CaseIterable.Type).allCasesArray
                return (enumSchema, allCases.first! as! T)
            }

            // 3. Recursive decode
            let nestedDecoder = DecoderImpl()
            let value = try T(from: nestedDecoder)

            if let recorder = nestedDecoder.propertyRecorder {
                var properties: [String: JSONSchema] = [:]
                var required: [String] = []
                for prop in recorder.properties {
                    properties[prop.name] = prop.schema
                    if prop.isRequired { required.append(prop.name) }
                }
                let schema = JSONSchema.object(
                    properties: properties,
                    required: required.isEmpty ? nil : required
                )
                return (schema, value)
            }

            if let unkeyedContainer = nestedDecoder.unkeyedContainerImpl {
                let itemSchema = unkeyedContainer.elementSchema ?? .string()
                let schema = JSONSchema.array(items: itemSchema)
                return (schema, value)
            }

            if let singleContainer = nestedDecoder.singleValueContainerImpl {
                return (singleContainer.recordedSchema ?? .string(), value)
            }

            return (.string(), value)
        }

        private func extractEnumSchema(_ type: (some Any).Type) -> JSONSchema? {
            guard let caseIterableType = type as? any CaseIterable.Type else {
                return nil
            }
            let cases = caseIterableType.allCasesArray.compactMap { value -> String? in
                if let rawRepresentable = value as? any RawRepresentable {
                    return "\(rawRepresentable.rawValue)"
                }
                return nil
            }
            guard !cases.isEmpty else { return nil }
            return .string(enum: cases)
        }
    }
}

// MARK: - UnkeyedContainerImpl

extension SchemaExtractingDecoder {
    final class UnkeyedContainerImpl: UnkeyedDecodingContainer {
        var codingPath: [CodingKey]
        var count: Int? = 1
        var isAtEnd: Bool {
            currentIndex >= 1
        }

        var currentIndex: Int = 0
        var elementSchema: JSONSchema?

        init(codingPath: [CodingKey]) {
            self.codingPath = codingPath
        }

        func decodeNil() throws -> Bool {
            false
        }

        func decode(_: Bool.Type) throws -> Bool {
            elementSchema = .boolean(); currentIndex += 1; return false
        }

        func decode(_: String.Type) throws -> String {
            elementSchema = .string(); currentIndex += 1; return ""
        }

        func decode(_: Double.Type) throws -> Double {
            elementSchema = .number(); currentIndex += 1; return 0.0
        }

        func decode(_: Float.Type) throws -> Float {
            elementSchema = .number(); currentIndex += 1; return 0.0
        }

        func decode(_: Int.Type) throws -> Int {
            elementSchema = .integer(); currentIndex += 1; return 0
        }

        func decode(_: Int8.Type) throws -> Int8 {
            elementSchema = .integer(); currentIndex += 1; return 0
        }

        func decode(_: Int16.Type) throws -> Int16 {
            elementSchema = .integer(); currentIndex += 1; return 0
        }

        func decode(_: Int32.Type) throws -> Int32 {
            elementSchema = .integer(); currentIndex += 1; return 0
        }

        func decode(_: Int64.Type) throws -> Int64 {
            elementSchema = .integer(); currentIndex += 1; return 0
        }

        func decode(_: UInt.Type) throws -> UInt {
            elementSchema = .integer(); currentIndex += 1; return 0
        }

        func decode(_: UInt8.Type) throws -> UInt8 {
            elementSchema = .integer(); currentIndex += 1; return 0
        }

        func decode(_: UInt16.Type) throws -> UInt16 {
            elementSchema = .integer(); currentIndex += 1; return 0
        }

        func decode(_: UInt32.Type) throws -> UInt32 {
            elementSchema = .integer(); currentIndex += 1; return 0
        }

        func decode(_: UInt64.Type) throws -> UInt64 {
            elementSchema = .integer(); currentIndex += 1; return 0
        }

        func decode<T: Decodable>(_ type: T.Type) throws -> T {
            currentIndex += 1

            if let leafType = type as? any SchemaLeaf.Type {
                elementSchema = leafType.jsonSchema
                return leafType.schemaPlaceholder as! T
            }

            if let caseIterableType = type as? any CaseIterable.Type {
                let cases = caseIterableType.allCasesArray.compactMap { value -> String? in
                    if let rawRepresentable = value as? any RawRepresentable {
                        return "\(rawRepresentable.rawValue)"
                    }
                    return nil
                }
                if !cases.isEmpty {
                    elementSchema = .string(enum: cases)
                    return caseIterableType.allCasesArray.first! as! T
                }
            }

            let nestedDecoder = DecoderImpl()
            let value = try T(from: nestedDecoder)

            if let recorder = nestedDecoder.propertyRecorder {
                var properties: [String: JSONSchema] = [:]
                var required: [String] = []
                for prop in recorder.properties {
                    properties[prop.name] = prop.schema
                    if prop.isRequired { required.append(prop.name) }
                }
                elementSchema = .object(
                    properties: properties,
                    required: required.isEmpty ? nil : required
                )
            }

            return value
        }

        func nestedContainer<NestedKey: CodingKey>(keyedBy _: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
            KeyedDecodingContainer(KeyedContainerImpl<NestedKey>(codingPath: codingPath, recorder: PropertyRecorder()))
        }

        func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            UnkeyedContainerImpl(codingPath: codingPath)
        }

        func superDecoder() throws -> Decoder {
            DecoderImpl()
        }
    }
}

// MARK: - SingleValueContainerImpl

extension SchemaExtractingDecoder {
    final class SingleValueContainerImpl: SingleValueDecodingContainer {
        var codingPath: [CodingKey]
        var recordedSchema: JSONSchema?

        init(codingPath: [CodingKey]) {
            self.codingPath = codingPath
        }

        func decodeNil() -> Bool {
            false
        }

        func decode(_: Bool.Type) throws -> Bool {
            recordedSchema = .boolean(); return false
        }

        func decode(_: String.Type) throws -> String {
            recordedSchema = .string(); return ""
        }

        func decode(_: Double.Type) throws -> Double {
            recordedSchema = .number(); return 0.0
        }

        func decode(_: Float.Type) throws -> Float {
            recordedSchema = .number(); return 0.0
        }

        func decode(_: Int.Type) throws -> Int {
            recordedSchema = .integer(); return 0
        }

        func decode(_: Int8.Type) throws -> Int8 {
            recordedSchema = .integer(); return 0
        }

        func decode(_: Int16.Type) throws -> Int16 {
            recordedSchema = .integer(); return 0
        }

        func decode(_: Int32.Type) throws -> Int32 {
            recordedSchema = .integer(); return 0
        }

        func decode(_: Int64.Type) throws -> Int64 {
            recordedSchema = .integer(); return 0
        }

        func decode(_: UInt.Type) throws -> UInt {
            recordedSchema = .integer(); return 0
        }

        func decode(_: UInt8.Type) throws -> UInt8 {
            recordedSchema = .integer(); return 0
        }

        func decode(_: UInt16.Type) throws -> UInt16 {
            recordedSchema = .integer(); return 0
        }

        func decode(_: UInt32.Type) throws -> UInt32 {
            recordedSchema = .integer(); return 0
        }

        func decode(_: UInt64.Type) throws -> UInt64 {
            recordedSchema = .integer(); return 0
        }

        func decode<T: Decodable>(_ type: T.Type) throws -> T {
            if let leafType = type as? any SchemaLeaf.Type {
                recordedSchema = leafType.jsonSchema
                return leafType.schemaPlaceholder as! T
            }
            recordedSchema = .string()
            let nestedDecoder = DecoderImpl()
            return try T(from: nestedDecoder)
        }
    }
}

// MARK: - CaseIterable Helper

private extension CaseIterable {
    static var allCasesArray: [Any] {
        Array(allCases) as [Any]
    }
}

// MARK: - JSONSchema Description Helper

extension JSONSchema {
    /// Returns a new schema with the given description, preserving all other fields.
    func withDescription(_ description: String) -> JSONSchema {
        JSONSchema(
            type: type,
            properties: properties,
            items: items,
            required: required,
            description: description,
            enum: `enum`
        )
    }
}
