@attached(
  member,
  names: named(RouteView),
  named(RouteSet),
  named(_routerEnvironmentKey),
  named(Handles),
  named(Provider),
  named(Link),
  named(routes),
  named(router)
)
public macro Routes(mode: RoutesMode = .path) =
  #externalMacro(module: "ElementaryRouterMacros", type: "RoutesMacro")

public enum RoutesMode {
  case path
  case hash
}

@attached(peer, names: arbitrary)
public macro Route(_ path: String) =
  #externalMacro(module: "ElementaryRouterMacros", type: "RouteMacro")

@attached(peer, names: arbitrary)
public macro Layout(_ path: String) =
  #externalMacro(module: "ElementaryRouterMacros", type: "LayoutMacro")

@attached(peer, names: arbitrary)
public macro NotFound() = #externalMacro(module: "ElementaryRouterMacros", type: "NotFoundMacro")

@attached(peer, names: arbitrary)
public macro RouteError() =
  #externalMacro(module: "ElementaryRouterMacros", type: "RouteErrorMacro")
