import ElementaryRouter
import ElementaryUI

/// A feature named `Routes`, like the feature of `SameNameFeatureAlpha`, with other routes.
///
/// The attribute is module-qualified because this module declares a type named `Routes`.
@ElementaryRouter.Routes
public struct Routes<Root: View> {
  @Route("/")
  public static func index() -> EmptyHTML {
    EmptyHTML()
  }

  @Route("/notes/:slug")
  public static func note(slug: String) -> EmptyHTML {
    EmptyHTML()
  }
}
