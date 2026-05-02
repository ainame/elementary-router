# ElementaryRouter

`ElementaryRouter` is a URL state router for ElementaryUI on Swift/WASM.

The preferred API is macro-based. `@Routes` generates a single typed route view, route handles, href helpers, and the `RouteTree` used by `Router`.

```swift
@Routes
struct AppRoutes {
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
  static func profile(
    lang: String,
    profileId: Int,
    tab: Query<String> = Query("overview")
  ) -> ProfilePage {
    ProfilePage(lang: lang, profileID: profileId, tab: tab.value)
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
```

Use the generated route set to create the router:

```swift
let routeSet = try AppRoutes.routes()
let router = Router(routes: routeSet.tree, history: .browser())
```

Render the current route with the generated typed route view:

```swift
RouterProvider(router) {
  RouterView(router) { _ in
    AppRoutes.RouteView(
      storage: .notFound(RouteNotFoundContext(location: router.location, query: RouteParameters()))
    )
  }
}
```

Generate links with route handles or generated href helpers:

```swift
Link(
  to: routeSet.handles.profile,
  params: ["lang": "ja", "profileId": 42],
  query: ["tab": "posts"]
) {
  "Profile"
}

let href = try routeSet.profileHref(lang: "ja", profileId: 42, tab: "posts")
```

`Link` preserves native browser behavior for modifier clicks and non-self targets. Full client-side interception still needs ElementaryUI to expose `MouseEvent.preventDefault()` or an equivalent cancellable event API.
