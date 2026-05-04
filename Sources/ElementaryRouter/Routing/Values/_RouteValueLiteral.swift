public struct _RouteValueLiteral: Equatable, Sendable {
  public let rawValue: String

  public init(_ value: some RouteValue) {
    self.rawValue = value.routeValueString
  }
}

extension _RouteValueLiteral: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self.rawValue = value
  }
}

extension _RouteValueLiteral: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) {
    self.rawValue = value.routeValueString
  }
}

extension _RouteValueLiteral: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) {
    self.rawValue = value.routeValueString
  }
}

extension _RouteValueLiteral: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) {
    self.rawValue = value.routeValueString
  }
}
