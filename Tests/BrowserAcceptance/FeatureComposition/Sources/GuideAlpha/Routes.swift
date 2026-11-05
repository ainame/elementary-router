import ElementaryRouter
import ElementaryUI

/// A feature named `Routes`, like the feature of `GuideBeta` and like the path-mode host.
///
/// The attribute is module-qualified because this module declares a type named `Routes`.
@ElementaryRouter.Routes
public struct Routes<Root: View> {
  @Route("/")
  public static func index() -> GuidePage<Root> {
    GuidePage(page: "guide-alpha")
  }

  @Route("/items")
  public static func items() -> GuidePage<Root> {
    GuidePage(page: "guide-alpha-items")
  }
}

/// Links to its own feature's routes through the route set it reads from the environment, so
/// its hrefs show which route set it received.
@View
public struct GuidePage<Root: View> {
  @Environment(Routes<Root>.RouteSet.self) var guide: Routes<Root>.RouteSet?

  let page: String

  public var body: some View {
    article(.id("page"), .data("page", value: page)) {
      h1 { page }
      if let guide {
        span(.id("guide-self")) {
          RouteLink(to: guide.index()) { "Alpha guide" }
        }
        span(.id("guide-items")) {
          RouteLink(to: guide.items()) { "Alpha items" }
        }
      } else {
        span(.id("guide-missing")) { "No alpha route set" }
      }
    }
  }
}
