public enum RouteValueError: Error, Equatable, Sendable {
  case missing(name: String)
  case invalid(name: String, rawValue: String, expected: String)
}

public protocol RouteValue: Sendable {
  static var routeValueTypeName: String { get }
  static func parseRouteValue(_ rawValue: String) -> Self?
  var routeValueString: String { get }
}

public struct RouteValueLiteral: Equatable, Sendable {
  public let rawValue: String

  public init(_ value: some RouteValue) {
    self.rawValue = value.routeValueString
  }
}

extension RouteValueLiteral: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self.rawValue = value
  }
}

extension RouteValueLiteral: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) {
    self.rawValue = value.routeValueString
  }
}

extension RouteValueLiteral: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) {
    self.rawValue = value.routeValueString
  }
}

extension RouteValueLiteral: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) {
    self.rawValue = value.routeValueString
  }
}

extension String: RouteValue {
  public static var routeValueTypeName: String { "String" }
  public static func parseRouteValue(_ rawValue: String) -> String? { rawValue }
  public var routeValueString: String { self }
}

extension Int: RouteValue {
  public static var routeValueTypeName: String { "Int" }
  public static func parseRouteValue(_ rawValue: String) -> Int? { Int(rawValue) }
  public var routeValueString: String { "\(self)" }
}

extension Double: RouteValue {
  public static var routeValueTypeName: String { "Double" }
  public static func parseRouteValue(_ rawValue: String) -> Double? { Double(rawValue) }
  public var routeValueString: String { "\(self)" }
}

extension Bool: RouteValue {
  public static var routeValueTypeName: String { "Bool" }

  public static func parseRouteValue(_ rawValue: String) -> Bool? {
    switch rawValue {
    case "true", "1": true
    case "false", "0": false
    default: nil
    }
  }

  public var routeValueString: String { self ? "true" : "false" }
}

public struct RouteParameters: Equatable, Sendable, ExpressibleByDictionaryLiteral {
  private var storage: [String: [String]]
  private var order: [(String, String)]

  public init() {
    self.storage = [:]
    self.order = []
  }

  public init(_ values: (String, RouteValueLiteral)...) {
    self.init()
    for (name, value) in values {
      append(name, value.rawValue)
    }
  }

  public init(dictionaryLiteral elements: (String, RouteValueLiteral)...) {
    self.init()
    for (name, value) in elements {
      append(name, value.rawValue)
    }
  }

  public func contains(_ name: String) -> Bool {
    storage[name] != nil
  }

  public func get(_ name: String) -> String? {
    storage[name]?.first
  }

  public func get<T: RouteValue>(_ name: String, _ type: T.Type) -> T? {
    guard let rawValue = get(name) else { return nil }
    return T.parseRouteValue(rawValue)
  }

  public func all(_ name: String) -> [String] {
    storage[name] ?? []
  }

  public func require(_ name: String) throws(RouteValueError) -> String {
    guard let value = get(name) else {
      throw RouteValueError.missing(name: name)
    }
    return value
  }

  public func require<T: RouteValue>(_ name: String, _ type: T.Type) throws(RouteValueError) -> T {
    guard let rawValue = get(name) else {
      throw RouteValueError.missing(name: name)
    }
    guard let value = T.parseRouteValue(rawValue) else {
      throw RouteValueError.invalid(name: name, rawValue: rawValue, expected: T.routeValueTypeName)
    }
    return value
  }

  public func set(_ name: String, _ value: some RouteValue) -> RouteParameters {
    var copy = self
    copy.storage[name] = [value.routeValueString]
    copy.rebuildOrderReplacing(name, with: [value.routeValueString])
    return copy
  }

  public func append(_ name: String, _ value: some RouteValue) -> RouteParameters {
    var copy = self
    copy.append(name, value.routeValueString)
    return copy
  }

  public var pairs: [(String, String)] {
    order
  }

  public func containsAll(_ expected: RouteParameters) -> Bool {
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

  public static func == (lhs: RouteParameters, rhs: RouteParameters) -> Bool {
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
