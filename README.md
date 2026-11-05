# ElementaryRouter

`ElementaryRouter` is a URL state router for ElementaryUI on Swift/WASM.

The 0.0.1 API is macro-based. `@Routes` generates a single typed route view,
typed navigation destinations, and route-set-specific router, provider, and
link views. This keeps
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

If you need programmatic access to the route set or the router, build the route
set explicitly and render with that same route set and router:

```swift
let routes = try AppRoutes.routes()
let router = routes.router()

let app = Application(AppRoutes.RouterView(routes, router: router))
app.mount(in: .body)

try router.navigate(to: routes.profile(lang: "ja", profileId: 42))
```

Each `routes()` call registers a new set of routes. Destinations and handles
belong to the route set that registered them, so one from a separate `routes()`
call is rejected: `href(to:)`, `navigate(to:)`, and `replace(to:)` throw
`RouteMatchError.foreignRoute`, and `isActive` returns `false`. A destination
from another `@Routes` type does not compile, because `RouteDestination` is
generic over that type's generated `RouteView`.
`AppRoutes.RouterView(routes, router:)` and `AppRoutes.Provider(routes, router:)`
stop with a precondition failure when the router was not created by
`routes.router()`.

Use hash routing explicitly when you need static-hosting fallback:

```swift
@Routes(mode: .hash)
struct DocsRoutes { ... }

let app = Application(DocsRoutes.RouterView())
```

In hash mode, `HashRouter.href(to:)`, `DocsRoutes.RouteSet.href(to:)`, and
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

## Typed Destinations

Every `@Route` gets a destination factory on the generated route set, named
after the route function and taking its path, wildcard, and query values with
their declared types:

```swift
let profile = try routes.profile(lang: "ja", profileId: 42, tab: "posts", hash: "bio")
```

A missing argument, a wrong label, or a value of the wrong type is a compile
error. The factory returns a `RouteDestination<AppRoutes.RouteView>`, and that
one value drives links, hrefs, programmatic navigation, and active checks in
both path and hash mode:

```swift
AppRoutes.Link(to: profile) {
  "Profile"
}

let href = try routes.href(to: profile)   // "/ja/profile/42?tab=posts#bio"
try router.navigate(to: profile)
try router.replace(to: profile)
let isActive = router.isActive(profile)
```

Types alone do not make every URL valid, so building a destination validates
it and throws `RouteMatchError`:

- `missingRequiredParameter` when a path value is empty, because the segment
  would collapse
- `invalidPathSegment` when a path value is `.` or `..`, or a wildcard value
  has a `.` or `..` component or an empty component from a leading, trailing,
  or repeated `/`. Browsers resolve or collapse such segments, and percent
  encoding cannot prevent it because URL parsers also resolve `%2E` forms. The
  value is rejected in hash mode too, so a destination is valid in both modes
  or in neither. Dots inside a segment, such as `a.b` or `...`, encoded slashes
  in path values, and unicode are kept.
- `invalidValue` when a value encodes to a string that its `RouteValue` type
  cannot decode again, such as a custom type with an invalid instance
- `unroutableLocation` when the URL resolves to another route, such as
  `user(name: "new")` on `/users/:name` next to `/users/new`, or
  `docs(splat: "")` on `/docs/*` next to `/docs`

Routes without path or wildcard values, whose query values use only `String`,
`Int`, `Double`, or `Bool`, cannot fail, so their factories do not throw:

```swift
AppRoutes.Link(to: routes.home()) {
  "Home"
}
```

A defaulted query parameter, such as `tab: Query<String> = Query("overview")`,
becomes an optional factory argument. Omitting it keeps it out of the URL and
the route renders its default; passing the default value writes it explicitly.

`router.isActive(destination)` is `true` when the current leaf route and path
values equal the destination's and every query value the destination wrote is
present. Pass `includeQuery: false` to ignore the query and `includeHash: true`
to also compare the fragment. Use `router.isActive(routes.handles.layout,
options: .descendant)` to check whether a layout encloses the current route.

Layouts never match a location on their own, so they have handles but no
destination factory.

`RouteHandle` with `RouteValues`, such as `router.navigate(to: handle, params:
["id": 42])`, remains as a low-level, untyped API for manually built route trees.
It applies the same validation, including `unroutableLocation` for layout
handles. `router.navigate(to: RouteLocation(url: "/raw?path"))` is the
unvalidated escape hatch for raw URLs.

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
- `AppRoutes.Handles`: named low-level route handles, including layouts
- `AppRoutes.RouteSet`: the generated handles, a typed destination factory for
  each route, `href(to:)`, and `router()` to create the typed router for the
  declared routing mode
- `AppRoutes.Provider`: installs a route set and its router for the content below it
- `AppRoutes.RouterView`: a typed route boundary that renders the current route,
  either for a route set and router you pass in or for ones it creates itself
- `AppRoutes.Link`: a link view for a destination of this route set
- `AppRoutes.routes()`: the factory used to build a route set

Route names `tree`, `handles`, `router`, and `href`, and route parameters named
`hash`, are rejected at compile time because they collide with generated API.

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

The generated destination factory and handle use the route function name:

```swift
try routes.profile(lang: "ja", profileId: 42, tab: "posts")
routes.handles.profile
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

A path containing a `.` or `..` segment, including `%2E` forms, matches no
route and renders `@NotFound`. In path mode the browser resolves such segments
before the router sees them; raw `RouteLocation` navigation and hash fragments
are not resolved, so the router rejects them to behave the same in both modes.
Route paths cannot declare static dot segments: `@Routes` reports them at
compile time and `RouteBuilder._build()` throws `RouteTreeError.dotSegment`.

Routes that match exactly the same URLs are rejected. `@Routes` reports them at
compile time and `RouteBuilder._build()` throws `RouteTreeError`:

- `duplicateRoute` for the same path declared twice, including trailing-slash variants
- `ambiguousRoute` for paths that differ only by parameter names, such as
  `/users/:id` and `/users/:name`, or by percent-encoding, such as `/café` and
  `/caf%C3%A9`
- `invalidWildcard` when `*` is not the last path segment

Empty path parameter values throw `RouteMatchError.missingRequiredParameter`
when a destination or href is built, because the empty segment would collapse
and the URL would no longer match the route. A URL claimed by a route with
higher precedence throws `RouteMatchError.unroutableLocation`.
- `@Layout` composes nested route UI through `Outlet<Content>`; keep durable app state above the router view.
- `@NotFound` and `@RouteError` keep fallback policy on route configuration, not inside page view bodies.
- `RouteValues` is used for both path params and query params.
- `Query<T>` maps query values into typed route function parameters.
- `Wildcard` maps `*` routes into a typed route function parameter.

## Link Interception Status

Generated route-set links such as `AppRoutes.Link` emit a normal anchor whose
`href` comes from the destination and the route set's mode, so it never depends
on a router and never falls back to `#`. When the environment provides this
route set's router and that router accepts the destination, the anchor also
gets `data-router-link="true"` and ElementaryUI's Swift `onClick` handler calls
router navigation only for eligible clicks:

- left button
- no modifier keys
- no non-self target

Modifier clicks, middle clicks, and `_blank` targets stay native browser
behavior. Without a provided router, or with a destination from another
`routes()` call, the link stays a plain anchor and the browser performs a normal
document navigation to the same href.

`AppRoutes.Provider(routes, router:)` installs a route set and the concrete
`Router<AppRoutes.RouteView>` or `HashRouter<AppRoutes.RouteView>` created by
that route set in ElementaryUI's environment. `AppRoutes.RouterView` installs
its route set and router through the provider, and `AppRoutes.Link(to:)` reads
the typed router back without existential erasure. Views that build
destinations read the route set from `AppRoutes._routeSetEnvironmentKey`, which
is `nil` outside a provider; handle that case explicitly instead of trapping in
a view body.

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
- typed destinations for links, hrefs, navigation, and active matching
- not-found and route-error fallback rendering
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
