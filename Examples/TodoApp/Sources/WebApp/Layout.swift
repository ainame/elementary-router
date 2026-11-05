import ElementaryRouter
import ElementaryUI

@View
struct FilterLink {
  @Environment(AppRoutes._routerEnvironmentKey) var router

  let title: String
  let destination: RouteDestination<AppRoutes.RouteView>

  var body: some View {
    span(.style(filterLinkStyle(isActive: router?.isActive(destination) ?? false))) {
      AppRoutes.Link(to: destination) {
        title
      }
    }
  }
}
