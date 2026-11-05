import Reactivity

/// A value that a host's generated `Provider` installs in the environment by its type.
///
/// ElementaryUI identifies such values by `ObjectIdentifier` of their class, so every
/// specialization is its own key: `ShopRoutes<AppRoutes.RouteView>.RouteSet` and
/// `ShopRoutes<OtherRoutes.RouteView>.RouteSet` never share a value, and neither do two features
/// that have the same name in different modules. Views read them with
/// `@Environment(ShopRoutes<Root>.RouteSet.self) var shop: ShopRoutes<Root>.RouteSet?` and
/// `@Environment(RouteNavigator<Root>.self) var navigator: RouteNavigator<Root>?`.
///
/// Generated feature route sets and `RouteNavigator` conform to it; it has no requirements.
public protocol _RouteEnvironmentObject: ReactiveObject {}

extension _RouteEnvironmentObject {
  /// The identity under which the environment stores this type, as ElementaryUI derives it for
  /// reactive objects.
  ///
  /// Generated hosts compare the identities of their mounted feature route sets, so one feature
  /// type mounted twice is found however its aliases spell it.
  public static var _environmentIdentity: ObjectIdentifier {
    ObjectIdentifier(self)
  }
}
