import ElementaryRouter
import ElementaryUI

/// The blog feature. A host mounts it with `@Mount("/blog") typealias Blog = BlogRoutes<RouteView>`.
///
/// `Root` is the host's route view. Blog views are generic over it, so they can hold the host's
/// typed destinations without knowing the host.
@Routes
public struct BlogRoutes<Root: View> {
  @Route("/")
  public static func posts() -> BlogIndexPage<Root> {
    BlogIndexPage()
  }

  @Route("/:slug")
  public static func post(slug: String) -> BlogPostPage<Root> {
    BlogPostPage(slug: slug)
  }
}

/// A blog post, looked up by its slug.
public struct BlogPost: Sendable {
  public let slug: String
  public let title: String

  public static let all: [BlogPost] = [
    BlogPost(slug: "teapot-review", title: "Review: the cast-iron teapot"),
    BlogPost(slug: "mug-review", title: "Review: the stoneware mug"),
  ]

  public static func named(_ slug: String) -> BlogPost? {
    all.first { $0.slug == slug }
  }
}
