// expected-error: Query `path` of layout `docsLayout` has the same name as a path or wildcard parameter
import ElementaryRouter
import ElementaryUI

@View
struct DocsShell<Content: View> {
  let outlet: Outlet<Content>

  var body: some View {
    outlet
  }
}

// The `docs` factory would take the layout's `path` query and the route's `path` wildcard.
@Routes
struct DocsRoutes {
  @Layout("/docs")
  static func docsLayout<Content: View>(
    path: Query<String> = Query(""),
    outlet: Outlet<Content>
  ) -> DocsShell<Content> {
    DocsShell(outlet: outlet)
  }

  @Route("/docs/*")
  static func docs(path: Wildcard) -> EmptyHTML {
    EmptyHTML()
  }
}
