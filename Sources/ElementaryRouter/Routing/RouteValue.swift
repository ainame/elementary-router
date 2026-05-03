public protocol RouteValue: Sendable {
  static var routeValueTypeName: String { get }
  static func parseRouteValue(_ rawValue: String) -> Self?
  var routeValueString: String { get }
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
