/// A stream of ``Operation`` events emitted by a running ``Operative``.
public typealias OperationStream = AsyncStream<Operation>

public extension AsyncStream where Element == Operation {
    /// Consumes the stream and returns the final result.
    ///
    /// Iterates through all events, returning the ``OperativeResult``
    /// from a ``Operation/completed(_:)`` event. Throws if the stream
    /// ends with ``Operation/stopped(_:)`` or without a terminal event.
    ///
    /// ```swift
    /// let result = try await operative.run("What's 2 + 2?").result()
    /// print(result.text ?? "")
    /// ```
    func result() async throws -> OperativeResult {
        for await operation in self {
            switch operation {
            case let .completed(result):
                return result
            case let .stopped(reason):
                throw OperativeError.stopped(reason)
            default:
                continue
            }
        }
        throw OperativeError.unexpectedEnd
    }
}
