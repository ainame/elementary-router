// expected-error: `basePath` only applies to path mode
import ElementaryRouter
import ElementaryUI

// Hash-mode hrefs are fragments that resolve against the document URL, which already includes
// the path the app is served under, so a base path would be applied twice.
@Routes(mode: .hash, basePath: "/my-app")
public struct HashBasePathRoutes {
  @Route("/")
  public static func home() -> EmptyHTML {
    EmptyHTML()
  }
}
