import ElementaryUI

struct CompiledRouteRecord<RouteContent: View> {
  let handle: RouteHandle
  let parent: RouteHandle?
  let pattern: RoutePattern
  let render: (RouteContext) throws(RouteValueError) -> RouteContent
}
