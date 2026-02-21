import Foundation

/// A convenience typealias requiring types to be Codable, Equatable, Hashable, and Sendable.
public typealias Friendly = Codable & Equatable & Hashable & Sendable
