public struct RouteErrorContext: Sendable {
  public let error: RouteValueError
  public let routeContext: RouteContext

  public init(error: RouteValueError, routeContext: RouteContext) {
    self.error = error
    self.routeContext = routeContext
  }
}
