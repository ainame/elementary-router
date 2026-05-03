import ElementaryUI

protocol RouterNavigation: AnyObject {
  func href(
    to route: RouteHandle,
    params: RouteParameters,
    query: RouteParameters,
    hash: String
  ) throws(RouteMatchError) -> String

  func navigate(
    to route: RouteHandle,
    params: RouteParameters,
    query: RouteParameters,
    hash: String,
    replace: Bool
  ) throws(RouteMatchError)
}

extension EnvironmentValues {
  @Entry var router: (any RouterNavigation)? = nil
}
