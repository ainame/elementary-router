// expected-error: BlogRoutes\.RouteView
import ElementaryRouter
import ElementaryUI
import RouteFixtures

// A destination of one route group cannot be used with another group's generated link.
public func linkToAnotherRouteGroup(post: RouteDestination<BlogRoutes.RouteView>) {
  _ = ShopRoutes.Link(to: post) { EmptyHTML() }
}
