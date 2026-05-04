struct RouteMatch: Equatable, Sendable {
  let route: RouteHandle
  let path: String
  let params: RouteParameters
}
