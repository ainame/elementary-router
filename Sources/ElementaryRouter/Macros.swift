@attached(member, names: named(RouteView), named(RouteSet), named(Handles), named(routes))
public macro Routes() = #externalMacro(module: "ElementaryRouterMacros", type: "RoutesMacro")

@attached(peer, names: arbitrary)
public macro Route(_ path: String) =
  #externalMacro(module: "ElementaryRouterMacros", type: "RouteMacro")

@attached(peer, names: arbitrary)
public macro NotFound() = #externalMacro(module: "ElementaryRouterMacros", type: "NotFoundMacro")

@attached(peer, names: arbitrary)
public macro RouteError() =
  #externalMacro(module: "ElementaryRouterMacros", type: "RouteErrorMacro")
