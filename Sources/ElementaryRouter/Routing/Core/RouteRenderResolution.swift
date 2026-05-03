enum RouteRenderResolution: Sendable {
  case matched(RouteContext)
  case notFound(RouteNotFoundContext)
  case error(RouteErrorContext)
}
