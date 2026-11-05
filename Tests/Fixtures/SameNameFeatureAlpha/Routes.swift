import ElementaryRouter
import ElementaryUI

/// A feature named `Routes`, like the feature of `SameNameFeatureBeta`.
///
/// The attribute is module-qualified because this module declares a type named `Routes`.
@ElementaryRouter.Routes
public struct Routes<Root: View> {
  @Route("/")
  public static func index() -> EmptyHTML {
    EmptyHTML()
  }

  @Route("/entries/:id")
  public static func entry(id: Int) -> EmptyHTML {
    EmptyHTML()
  }
}
