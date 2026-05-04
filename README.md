# ElementaryRouter

`ElementaryRouter` is a URL state router for ElementaryUI on Swift/WASM.

The 0.0.1 API is macro-based. `@Routes` generates a single typed route view,
route handles, href helpers, and typed router helpers. This keeps
route rendering on upstream ElementaryUI without a vendored `AnyView` or runtime
type-erased view layer.

## Installation

Add the package to `Package.swift`:

```swift
.package(url: "https://github.com/ainame/elementary-router", exact: "0.0.1")
```

Then depend on the library product:

```swift
.product(name: "ElementaryRouter", package: "elementary-router")
```

## Basic Usage

Define routes with `@Routes`:

```swift
import ElementaryRouter
import ElementaryUI

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

For normal apps, mount the generated router view directly:

```swift
let app = Application(AppRoutes.RouterView())
app.mount(in: .body)
```

If you need programmatic access to generated handles, href helpers, or the router,
build the route set explicitly:

```swift
let routes = try AppRoutes.routes()
let router = routes.router()
```

Use hash routing explicitly when you need static-hosting fallback:

```swift
@Routes(mode: .hash)
struct DocsRoutes { ... }

let app = Application(DocsRoutes.RouterView())
```

The generated router view creates the concrete router and renders the current route:

```swift
let app = Application(AppRoutes.RouterView())
app.mount(in: .body)
```

Put visible app chrome in a route layout, so the app entry point only mounts routing:

```swift
@Layout("/")
static func contentView<Content: View>(outlet: Outlet<Content>) -> ContentView<Content> {
  ContentView(outlet: outlet)
}
```

Generate links with route handles or generated href helpers:

```swift
AppRoutes.Link(
  to: routes.handles.profile,
  params: ["lang": "ja", "profileId": 42],
  query: ["tab": "posts"]
) {
  "Profile"
}

let href = try routes.profileHref(lang: "ja", profileId: 42, tab: "posts")
```

## Macros

### `@Routes`

Attach `@Routes` to a `struct` that declares the route set:

```swift
@Routes
struct AppRoutes {
  // @Route, @Layout, @NotFound, and @RouteError declarations go here.
}
```

The macro generates:

- `AppRoutes.RouteView`: a single typed view union for all route outputs
- `AppRoutes.Handles`: named route handles
- `AppRoutes.RouteSet`: the generated handles plus router-aware href helpers
- `AppRoutes.Provider`: a typed router provider for this route declaration
- `AppRoutes.RouterView`: a typed route boundary that creates the router and renders the current route
- `AppRoutes.Link`: a typed link view for this route declaration
- `AppRoutes.routes()`: the factory used to build the generated route set
- `AppRoutes.router()`: the typed router factory for the declared routing mode
- route-specific href helpers, such as `profileHref(...)`

Route declarations must be `static func` members inside the `@Routes` struct.
The macro intentionally does not discover routes from extensions or unrelated
types.

### `@Route`

Use `@Route` for a leaf page route:

```swift
@Route("/:lang/profile/:profileId")
static func profile(
  lang: String,
  profileId: Int,
  tab: Query<String> = Query("overview")
) -> ProfilePage {
  ProfilePage(lang: lang, profileID: profileId, tab: tab.value)
}
```

Path parameters use `:name` syntax and must have matching function parameters.
Parameter values are decoded from strings using `RouteValue`. Built-in support
includes common scalar types such as `String`, `Int`, `Double`, and `Bool`.

Query parameters are declared with `Query<T>` function parameters. A default
value, such as `Query("overview")`, makes the query parameter optional for href
generation and route rendering.

Wildcard routes use `*` and must declare a `Wildcard` parameter:

```swift
@Route("/docs/*")
static func docs(splat: Wildcard) -> DocsPage {
  DocsPage(slug: splat.value)
}
```

The generated handle and href helper use the route function name:

```swift
routes.handles.profile
try routes.profileHref(lang: "ja", profileId: 42, tab: "posts")
```

### `@Layout`

Use `@Layout` for a parent route that wraps matching child routes:

```swift
@Layout("/:lang")
static func languageLayout<Content: View>(
  lang: String,
  outlet: Outlet<Content>
) -> LanguageLayout<Content> {
  LanguageLayout(lang: lang, outlet: outlet)
}
```

A layout route must accept `Outlet<Content>` and return a view that renders that
outlet. Child routes matched under the layout are composed into the outlet by
the generated typed `RouteView`.

### `@NotFound`

Use `@NotFound` to declare the route set's not-found fallback:

```swift
@NotFound
static func notFound(context: RouteNotFoundContext) -> NotFoundPage {
  NotFoundPage(path: context.location.path)
}
```

`RouteNotFoundContext` provides the requested `location` and parsed `query`.
For 0.0.1, this is route-set level fallback policy. Per-route not-found
propagation similar to TanStack Router is not implemented yet.

### `@RouteError`

Use `@RouteError` to declare the route set's route-value error fallback:

```swift
@RouteError
static func routeError(context: RouteErrorContext) -> InvalidRoutePage {
  InvalidRoutePage(error: context.error)
}
```

`RouteErrorContext` includes the `RouteValueError` and the route context that
failed to render. This currently handles route value decoding errors, such as
an invalid `Int` path parameter.

## Routing Model

- `Router.matchedRoutes` is the parent-to-leaf match stack.
- `Router.currentRoute` and `Router.currentParams` are leaf conveniences.
- `Router` uses standard browser path routing.
- `HashRouter` is available when you explicitly want hash-based routing.
- `@Layout` composes nested route UI through `Outlet<Content>`.
- `@NotFound` and `@RouteError` keep fallback policy on route configuration, not inside page view bodies.
- `RouteValues` is used for both path params and query params.
- `Query<T>` maps query values into typed route function parameters.
- `Wildcard` maps `*` routes into a typed route function parameter.

## Link Interception Status

Generated route-set links such as `AppRoutes.Link` emit a normal anchor with
`href` and `data-router-link="true"`, then use ElementaryUI's Swift `onClick`
handler to call router navigation only for
eligible clicks:

- left button
- no modifier keys
- no non-self target

Modifier clicks, middle clicks, and `_blank` targets stay native browser
behavior.

`AppRoutes.Provider` installs a concrete `Router<AppRoutes.RouteView>` or
`HashRouter<AppRoutes.RouteView>` in ElementaryUI's environment, and
`AppRoutes.RouterView` and `AppRoutes.Link(to:)` read that typed router back
without existential erasure.

One blocker remains outside ElementaryRouter: ElementaryUI currently exposes
mouse button and modifier-key state, but not a public way to call
`preventDefault()` from Swift. Until that exists, apps that want full
client-side navigation interception should add a capture-phase script to the
host HTML:

```html
<script>
document.addEventListener(
  "click",
  (event) => {
    const target =
      event.target instanceof Element ? event.target : event.target?.parentElement;
    const anchor = target?.closest("a[data-router-link]");
    if (!anchor || event.defaultPrevented) return;
    if (
      event.button !== 0 ||
      event.metaKey ||
      event.ctrlKey ||
      event.shiftKey ||
      event.altKey
    ) {
      return;
    }
    if (anchor.target && anchor.target !== "_self") return;
    if (anchor.hasAttribute("download")) return;
    if (new URL(anchor.href, location.href).origin !== location.origin) return;

    event.preventDefault();
  },
  true,
);
</script>
```

This is an app-level workaround for 0.0.1, not the final library contract. The
preferred fix is for ElementaryUI to expose `MouseEvent.preventDefault()` or an
equivalent cancellable event handler.

## Current Scope

In scope for 0.0.1:

- typed route registration with `@Routes`
- path params, wildcard params, and typed query params
- nested typed layouts with `@Layout` and `Outlet<Content>`
- browser routing, hash routing, and internal test adapters
- route handles, href helpers, active matching, not-found, and route-error fallback rendering
- typed route-set `Provider`, `RouterView`, and `Link` generation

Out of scope for 0.0.1:

- form actions and non-GET mutations
- server functions
- SSR and hydration
- loader caching
- runtime `AnyView` route rendering

## Example

Available examples:

- [Examples/RouterExample](Examples/RouterExample): a compact routing feature tour
- [Examples/TodoApp](Examples/TodoApp): a practical task manager with shared app state, filters, detail routes, and stats
