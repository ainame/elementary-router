import ElementaryUI

/// A validated navigation target for one registered route.
///
/// Generated route sets create destinations with typed factories, such as
/// `try routes.profile(lang: "ja", profileId: 42)`. A destination is built once and then used for
/// links, hrefs, programmatic navigation, and active checks, so all of them agree on the URL.
///
/// Building a destination encodes every value, builds the URL, and checks that the URL resolves
/// back to the same route. Typed factories catch missing and mistyped arguments at compile time,
/// but some values can still produce no valid URL, so factories that take such values throw
/// `RouteMatchError`.
///
/// The `RouteContent` argument is the generated route view of one `@Routes` type, so a
/// destination from another `@Routes` type does not compile with this route set's router or
/// links. Destinations from a separate `routes()` call of the same type are rejected at runtime
/// with `RouteMatchError.foreignRoute`.
public struct RouteDestination<RouteContent: View>: Equatable, Sendable {
  /// The registered route this destination targets.
  public let route: RouteHandle
  /// The encoded route location, such as `/users/42?tab=posts#bio`.
  ///
  /// Routers place this location in the browser path, or after `#` in hash mode.
  public let location: RouteLocation
  /// The decoded path parameter values, as the router reads them back from `location`.
  public let params: RouteValues
  /// The query values written to `location`. Omitted defaults are not included.
  public let query: RouteValues
  /// The decoded fragment, without a leading `#`.
  public let hash: String
}

extension RouteValues {
  /// Returns a copy with `name` set to `value`, after checking that the encoded value decodes
  /// back as `Value`.
  ///
  /// Generated destination factories use this so a value that the route could never read back
  /// fails while the destination is built instead of producing a URL that renders an error.
  public func _setting<Value: RouteValue>(
    _ name: String,
    _ value: Value
  ) throws(RouteMatchError) -> RouteValues {
    let rawValue = value.routeValueString
    guard Value.parseRouteValue(rawValue) != nil else {
      throw RouteMatchError.invalidValue(
        name: name,
        rawValue: rawValue,
        expected: Value.routeValueTypeName
      )
    }
    return set(name, value)
  }

  /// Returns `_setting(name, value)` for a present value, or an unchanged copy for `nil`.
  public func _settingIfPresent<Value: RouteValue>(
    _ name: String,
    _ value: Value?
  ) throws(RouteMatchError) -> RouteValues {
    guard let value else {
      return self
    }
    return try _setting(name, value)
  }
}
