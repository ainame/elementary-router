/// Converts a value between its typed form and its URL string representation.
///
/// `RouteValue` is used by `RouteValues`, route-path matching, and query decoding. Conforming
/// types must provide a stable string encoding and a parser from that encoding.
public protocol RouteValue: Sendable {
  /// Human-readable type name used in decoding errors.
  static var routeValueTypeName: String { get }
  /// Parses a typed value from a raw URL string.
  static func parseRouteValue(_ rawValue: String) -> Self?
  /// Encodes the value as a URL string.
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
