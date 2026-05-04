public struct RouteParameters: Equatable, Sendable, ExpressibleByDictionaryLiteral {
  private var storage: [String: [String]]
  private var order: [(String, String)]

  public init() {
    self.storage = [:]
    self.order = []
  }

  public init(_ values: (String, _RouteValueLiteral)...) {
    self.init()
    for (name, value) in values {
      append(name, value.rawValue)
    }
  }

  public init(dictionaryLiteral elements: (String, _RouteValueLiteral)...) {
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
