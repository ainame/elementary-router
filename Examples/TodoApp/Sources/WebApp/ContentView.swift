import ElementaryRouter
import ElementaryUI

@View
struct ContentView<Content: View> {
  @Environment(AppRoutes._routeSetEnvironmentKey) var routes
  @Environment(TodoStore.self) var store

  let outlet: Outlet<Content>

  var body: some View {
    let routes = routeSet

    div(.style(pageStyle)) {
      header(.style(headerStyle)) {
        div {
          p(.style(eyebrowStyle)) { "ElementaryRouter Example" }
          h1(.style(titleStyle)) { "Todo Planner" }
        }
        div(.style(summaryPillStyle)) {
          "\(store.activeCount) active / \(store.todos.count) total"
        }
      }

      nav(.style(navStyle)) {
        FilterLink(title: "All", route: routes.handles.allTasks)
        FilterLink(title: "Active", route: routes.handles.activeTasks)
        FilterLink(title: "Completed", route: routes.handles.completedTasks)
        FilterLink(title: "Stats", route: routes.handles.stats)
      }

      main(.style(mainStyle)) {
        outlet
      }
    }
    .environment(#Key(\.todoRouteSet), routes)
  }

  private var routeSet: AppRoutes.RouteSet {
    guard let routes else {
      preconditionFailure("ContentView requires AppRoutes.RouterView or AppRoutes.Provider.")
    }
    return routes
  }
}
