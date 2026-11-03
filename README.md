# ElementaryRouter

`ElementaryRouter` is a URL state router for ElementaryUI on Swift/WASM.

The 0.0.1 API is macro-based. `@Routes` generates a single typed route view,
route handles, href helpers, and typed router helpers. This keeps
route rendering on upstream ElementaryUI without a vendored `AnyView` or runtime
type-erased view layer.

## Installation

The package requires Swift 6.4 and ElementaryUI 0.9. Native macOS builds require
macOS 26 or later. The examples use the matching Swift 6.4 Embedded WebAssembly
SDK for their browser builds.

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
build the route set explicitly and render with that same route set and router:

```swift
let routes = try AppRoutes.routes()
let router = routes.router()

let app = Application(AppRoutes.RouterView(routes, router: router))
app.mount(in: .body)

try router.navigate(to: routes.handles.profile, params: ["lang": "ja", "profileId": 42])
```

Each `routes()` call registers a new set of route handles. Handles belong to the
route set that registered them, so a handle from another `@Routes` type, or from
a separate `routes()` call, is rejected: `href(to:)` and `navigate(to:)` throw
`RouteMatchError.foreignRoute`, and `isActive` returns `false`.
`AppRoutes.RouterView(routes, router:)` and `AppRoutes.Provider(routes, router:)`
stop with a precondition failure when the router was not created by
`routes.router()`.

Use hash routing explicitly when you need static-hosting fallback:

```swift
@Routes(mode: .hash)
struct DocsRoutes { ... }

let app = Application(DocsRoutes.RouterView())
```

In hash mode, `HashRouter.href(to:)`, generated href helpers, and
`DocsRoutes.Link` produce fragment hrefs such as `#/docs/guide?tab=api#install`.
The route path and query are encoded once and placed after `#`. Browsers
resolve a fragment href against the current document URL, so an app served
from `/app/?lang=en` links to `/app/?lang=en#/docs/guide?tab=api#install` for
normal clicks, modified clicks, and copied links, and client navigation keeps
the same base path and outer query string. Do not add a `<base href>` element
to hash-mode pages, because it changes how fragment hrefs resolve.

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
- `AppRoutes.RouteSet`: the generated handles plus href helpers, and
  `router()` to create the typed router for the declared routing mode
- `AppRoutes.Provider`: installs a route set and its router for the content below it
- `AppRoutes.RouterView`: a typed route boundary that renders the current route,
  either for a route set and router you pass in or for ones it creates itself
- `AppRoutes.Link`: a typed link view for this route declaration
- `AppRoutes.routes()`: the factory used to build a route set
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

A layout wraps every route and nested layout whose path starts with the
layout's path segments. Parameters must use the same names: `/:lang/profile/:id`
is wrapped by `@Layout("/:lang")`, while `/:slug/about` is not. Nested layouts
form the match stack from the outermost layout to the leaf route, so with
`@Layout("/")`, `@Layout("/:lang")`, and `@Route("/:lang/profile/:profileId")`,
`router.matchedRoutes` for `/ja/profile/42` is
`[contentView, languageLayout, profile]`.

Layouts are composition nodes, not pages. A layout never matches a location on
its own, so `/ja` above resolves to `@NotFound` unless an index route is
declared at the layout's path:

```swift
@Route("/:lang")
static func languageHome(lang: String) -> LanguageHomePage {
  LanguageHomePage(lang: lang)
}
```

Treat `@Layout` as route composition, not as an application state boundary.
The router may recreate layout view values while resolving a new location, so
state that must survive navigation should live above `AppRoutes.RouterView()`
and be passed through ElementaryUI's environment:

```swift
@View
struct AppRoot {
  @State var store = TodoStore()

  var body: some View {
    AppRoutes.RouterView()
      .environment(store)
  }
}
```

Layout views can read shared state from the environment, but they should not own
durable app state such as stores, sessions, or caches. This keeps route
composition close to TanStack Router's layout idea without making Swift view
identity part of the router's state model.

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

- `Router.matchedRoutes` is the parent-to-leaf match stack, including every enclosing layout.
- `Router.currentRoute` and `Router.currentParams` are leaf conveniences.
- `Router` uses standard browser path routing.
- `HashRouter` is available when you explicitly want hash-based routing; its hrefs are fragments like `#/users/42`.
- Route handles belong to the route set that registered them; see the identity rules above.
  `RouteBuilder._build()` throws `RouteTreeError.foreignParent` when a route names a
  parent handle registered by another builder.
- A router observes browser history from creation until it is released. Every
  navigation, including `pushState`-based client navigation, which does not emit
  `popstate`, and browser back and forward, updates the router state exactly once.

### Matching Precedence

Routes are ranked segment by segment, from left to right. At the first segment
where two routes differ, a static segment beats a parameter, and a parameter
beats a wildcard. A route that ends where another continues with `*` wins, so
`/files` is preferred over `/files/*` for `/files`. Registration order does not
affect matching. For example, `/docs/profile/1` matches `/docs/*` rather than
`/:lang/profile/:id`.

Static segments are compared after percent-decoding, so `@Route("/café")`
matches both `/café` and `/caf%C3%A9`. Generated hrefs percent-encode static
segments and parameter values, and parameter values are decoded when matched.

Routes that match exactly the same URLs are rejected. `@Routes` reports them at
compile time and `RouteBuilder._build()` throws `RouteTreeError`:

- `duplicateRoute` for the same path declared twice, including trailing-slash variants
- `ambiguousRoute` for paths that differ only by parameter names, such as
  `/users/:id` and `/users/:name`, or by percent-encoding, such as `/café` and
  `/caf%C3%A9`
- `invalidWildcard` when `*` is not the last path segment

Empty path parameter values throw `RouteMatchError.missingRequiredParameter`
when an href is built, because the empty segment would collapse and the URL
would no longer match the route.
- `@Layout` composes nested route UI through `Outlet<Content>`; keep durable app state above the router view.
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

`AppRoutes.Provider(routes, router:)` installs a route set and the concrete
`Router<AppRoutes.RouteView>` or `HashRouter<AppRoutes.RouteView>` created by
that route set in ElementaryUI's environment. `AppRoutes.RouterView` installs
its route set and router through the provider, and `AppRoutes.Link(to:)` reads
the typed router back without existential erasure.

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
