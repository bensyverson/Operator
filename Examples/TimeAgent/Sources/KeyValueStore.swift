import Foundation
import Operator
import Synchronization

struct KeyValueStore: Operable {
    let storage = Storage()

    var toolGroup: ToolGroup {
        let store = storage
        return ToolGroup(name: "Key-Value Store", description: "A simple in-memory key-value store", tools: [
            // swiftlint:disable:next force_try
            try! Tool(
                name: "kvSet",
                description: "Store a value under a key",
                input: SetInput.self
            ) { input in
                store.set(input.key, to: input.value)
                return ToolOutput("Stored '\(input.key)' = '\(input.value)'")
            },

            // swiftlint:disable:next force_try
            try! Tool(
                name: "kvGet",
                description: "Retrieve the value for a key",
                input: GetInput.self
            ) { input in
                if let value = store.get(input.key) {
                    ToolOutput("\(input.key) = \(value)")
                } else {
                    ToolOutput("No value found for key '\(input.key)'")
                }
            },

            Tool(name: "kvList", description: "List all stored key-value pairs") {
                let pairs = store.all()
                if pairs.isEmpty {
                    return ToolOutput("The store is empty.")
                }
                let lines = pairs.sorted(by: { $0.key < $1.key }).map { "\($0.key) = \($0.value)" }
                return ToolOutput(lines)
            },
        ])
    }

    // MARK: - Storage

    final class Storage: Sendable {
        private let data = Mutex<[String: String]>([:])

        func set(_ key: String, to value: String) {
            data.withLock { $0[key] = value }
        }

        func get(_ key: String) -> String? {
            data.withLock { $0[key] }
        }

        func all() -> [String: String] {
            data.withLock { $0 }
        }
    }

    // MARK: - Inputs

    struct SetInput: ToolInput {
        let key: String
        let value: String

        static var paramDescriptions: [String: String] {
            [
                "key": "The key to store the value under",
                "value": "The value to store",
            ]
        }
    }

    struct GetInput: ToolInput {
        let key: String

        static var paramDescriptions: [String: String] {
            [
                "key": "The key to retrieve",
            ]
        }
    }
}
