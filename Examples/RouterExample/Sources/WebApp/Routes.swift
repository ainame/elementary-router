import ElementaryRouter
import ElementaryUI

@Routes
struct AppRoutes {
  @Layout("/")
  static func contentView<Content: View>(outlet: Outlet<Content>) -> ContentView<Content> {
    ContentView(outlet: outlet)
  }

  @Layout("/:lang")
  static func languageLayout<Content: View>(
    lang: String,
    outlet: Outlet<Content>
  ) -> LanguageLayout<Content> {
    LanguageLayout(lang: lang, outlet: outlet)
  }

  @Route("/")
  static func home() -> HomePage {
    HomePage()
  }

  @Route("/:lang/profile/:profileId")
  static func profile(lang: String, profileId: Int) -> ProfilePage {
    ProfilePage(lang: lang, profileID: profileId)
  }

  @Route("/docs/*")
  static func docs(splat: Wildcard) -> DocsPage {
    DocsPage(slug: splat.value)
  }

  @NotFound
  static func notFound(context: RouteNotFoundContext) -> NotFoundPage {
    NotFoundPage(path: context.location.path)
  }

  @RouteError
  static func routeError(context: RouteErrorContext) -> InvalidRoutePage {
    InvalidRoutePage(error: context.error)
  }
}
