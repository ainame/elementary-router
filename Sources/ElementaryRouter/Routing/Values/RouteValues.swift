/// Ordered route and query values keyed by name.
///
/// `RouteValues` is the shared value container used for path parameters, query parameters, and
/// URL construction. It preserves insertion order so repeated query parameters can round-trip.
public struct RouteValues: Equatable, Sendable, ExpressibleByDictionaryLiteral {
  /// Literal wrapper used by dictionary and tuple-list initialization.
  public struct ValueLiteral: Equatable, Sendable {
    /// The encoded route value.
    public let rawValue: String

    /// Creates a literal wrapper from any route value.
    public init(_ value: some RouteValue) {
      self.rawValue = value.routeValueString
    }
  }

  private var storage: [String: [String]]
  private var order: [(String, String)]

  /// Creates an empty value collection.
  public init() {
    self.storage = [:]
    self.order = []
  }

  /// Creates a value collection from an ordered list of key-value pairs.
  public init(_ values: (String, ValueLiteral)...) {
    self.init()
    for (name, value) in values {
      append(name, value.rawValue)
    }
  }

  /// Creates a value collection from a dictionary literal.
  public init(dictionaryLiteral elements: (String, ValueLiteral)...) {
    self.init()
    for (name, value) in elements {
      append(name, value.rawValue)
    }
  }

  /// Returns `true` when at least one value exists for `name`.
  public func contains(_ name: String) -> Bool {
    storage[name] != nil
  }

  /// Returns the first raw string value for `name`.
  public func get(_ name: String) -> String? {
    storage[name]?.first
  }

  /// Returns the first decoded value for `name`.
  public func get<T: RouteValue>(_ name: String, _ type: T.Type) -> T? {
    guard let rawValue = get(name) else { return nil }
    return T.parseRouteValue(rawValue)
  }

  /// Returns all raw values for `name` in insertion order.
  public func all(_ name: String) -> [String] {
    storage[name] ?? []
  }

  /// Returns the first raw value for `name` or throws when it is missing.
  public func require(_ name: String) throws(RouteValueError) -> String {
    guard let value = get(name) else {
      throw RouteValueError.missing(name: name)
    }
    return value
  }

  /// Returns the first decoded value for `name` or throws when it is missing or invalid.
  public func require<T: RouteValue>(_ name: String, _ type: T.Type) throws(RouteValueError) -> T {
    guard let rawValue = get(name) else {
      throw RouteValueError.missing(name: name)
    }
    guard let value = T.parseRouteValue(rawValue) else {
      throw RouteValueError.invalid(name: name, rawValue: rawValue, expected: T.routeValueTypeName)
    }
    return value
  }

  /// Returns a copy with `name` replaced by a single encoded value.
  public func set(_ name: String, _ value: some RouteValue) -> RouteValues {
    var copy = self
    copy.storage[name] = [value.routeValueString]
    copy.rebuildOrderReplacing(name, with: [value.routeValueString])
    return copy
  }

  /// Returns a copy with an additional encoded value appended for `name`.
  public func append(_ name: String, _ value: some RouteValue) -> RouteValues {
    var copy = self
    copy.append(name, value.routeValueString)
    return copy
  }

  /// Returns the ordered key-value pairs stored in this collection.
  public var pairs: [(String, String)] {
    order
  }

  /// Returns `true` when all ordered pairs in `expected` exist in this collection.
  public func containsAll(_ expected: RouteValues) -> Bool {
    for pair in expected.pairs {
      if !all(pair.0).contains(pair.1) {
        return false
      }
    }
    return true
  }

  mutating func append(_ name: String, _ value: String) {
    storage[name, default: []].append(value)
    order.append((name, value))
  }

  private mutating func rebuildOrderReplacing(_ name: String, with values: [String]) {
    order.removeAll { $0.0 == name }
    for value in values {
      order.append((name, value))
    }
  }

  public static func == (lhs: RouteValues, rhs: RouteValues) -> Bool {
    guard lhs.order.count == rhs.order.count else { return false }
    for index in lhs.order.indices {
      guard lhs.order[index].0 == rhs.order[index].0,
        lhs.order[index].1 == rhs.order[index].1
      else {
        return false
      }
    }
    return true
  }
}

extension RouteValues.ValueLiteral: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self.rawValue = value
  }
}

extension RouteValues.ValueLiteral: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) {
    self.rawValue = value.routeValueString
  }
}

extension RouteValues.ValueLiteral: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) {
    self.rawValue = value.routeValueString
  }
}

extension RouteValues.ValueLiteral: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) {
    self.rawValue = value.routeValueString
  }
}
