import ElementaryRouter
import ElementaryUI

/// A public feature without layouts, compiled in its own module.
@Routes
public struct NewsRoutes<Root: View> {
  @Route("/")
  public static func index() -> NewsIndex<Root> {
    NewsIndex()
  }

  @Route("/:slug")
  public static func article(slug: String) -> EmptyHTML {
    EmptyHTML()
  }
}

@View
public struct NewsIndex<Root: View> {
  @Environment(NewsRoutes<Root>.RouteSet.self) var news: NewsRoutes<Root>.RouteSet?

  public var body: some View {
    if let news {
      RouteLink(to: news.index()) { "News" }
    }
  }
}
