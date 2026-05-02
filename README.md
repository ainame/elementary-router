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

## Known Link Interception Blocker

ElementaryUI currently exposes mouse button and modifier-key state, but not a public way to call `preventDefault()` from Swift. Until that exists, `Link` can call router navigation for eligible clicks but cannot stop the browser's native anchor navigation by itself.

For an app-level workaround, add a capture-phase script to the host HTML and mark router anchors, for example with `data-router-link`:

```html
<script>
document.addEventListener("click", event => {
  const anchor = event.target.closest("a[data-router-link]");
  if (!anchor || event.defaultPrevented) return;
  if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
  if (anchor.target && anchor.target !== "_self") return;
  if (anchor.hasAttribute("download")) return;
  if (new URL(anchor.href, location.href).origin !== location.origin) return;

  event.preventDefault();
}, true);
</script>
```

This is a workaround for controlled apps, not the final library contract. The preferred fix is for ElementaryUI to expose `MouseEvent.preventDefault()` or an equivalent cancellable event handler.
