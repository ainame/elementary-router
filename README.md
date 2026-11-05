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

`AppRoutes.RouterView()` owns its route set and router. They are created the
first time the mounted view renders and kept, together with the router's
browser history listener, until the view is unmounted; rebuilding the body of a
view that contains `RouterView()` does not create another route set or router.
A `RouterView()` mounted again later creates a new pair.

`AppRoutes.RouterView(routes, router:)` renders a pair you own instead. The view
keeps no copy of its own: when a rebuilt parent body supplies a different pair,
the view renders that pair from then on, and the previous router lives as long
as you keep it.

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

A route's factory also takes the query values of every layout above it, after
the route's own, from the outermost layout in. A query name is one URL value,
so a route and its layouts that declare the same name share one argument: it
is required when any of them declares it without a default, and otherwise
optional, and omitting it lets each declaration render its own default. With
`@Layout("/:lang/admin") admin(lang:level: Query<Int>, outlet:)`, the route
`@Route("/:lang/admin/users") adminUsers(lang:)` gets
`routes.adminUsers(lang: "en", level: 3)`.

A route and its layouts must declare a shared path parameter or query name with
one type; `@Routes` reports a mismatch, such as `id: Int` on a layout and
`id: String` on its route, a layout query with the name of a route path or
wildcard parameter, or a layout query named `hash`, and generates no code for
that route. Types are compared by spelling, because macros do not see resolved
types: `Int` and `Swift.Int` are the same, but a typealias and the type it
names, or a type qualified with another module name, are reported as
different. Spell a shared value's type the same way everywhere. Building a destination, including
the untyped `navigate(to: handle, params:query:)`, also checks that every
layout above the route can decode its values: a missing required layout query
throws `missingRequiredParameter`, and a value a layout cannot decode throws
`invalidValue`.

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

## Feature Composition

A feature module can declare routes that a host app mounts into its own route tree. The host
keeps one tree, one `Router` or `HashRouter`, its layouts, and its `@NotFound` and `@RouteError`
policy; the feature contributes typed routes, layouts, and views.

A feature is a `@Routes` struct with one generic parameter, the host's route view:

```swift
// Module Shop
@Routes
public struct ShopRoutes<Root: View> {
  @Layout("/")
  public static func shopLayout<Content: View>(outlet: Outlet<Content>) -> ShopLayout<Root, Content> {
    ShopLayout(outlet: outlet)
  }

  @Route("/")
  public static func catalog(sort: Query<String> = Query("name")) -> CatalogPage<Root> {
    CatalogPage(sort: sort.value)
  }

  @Route("/products/:id")
  public static func product(id: Int) -> ProductPage<Root> {
    ProductPage(id: id)
  }
}
```

The host mounts it at a static path with a type alias that specializes the feature with the
host's `RouteView`:

```swift
// Module WebApp
import Blog
import Shop

@Routes
struct AppRoutes {
  @Layout("/")
  static func shell<Content: View>(outlet: Outlet<Content>) -> AppShell<Content> {
    AppShell(outlet: outlet)
  }

  @Mount("/shop")
  typealias Shop = ShopRoutes<RouteView>

  @Mount("/blog")
  typealias Blog = BlogRoutes<RouteView>

  @NotFound
  static func notFound(context: RouteNotFoundContext) -> NotFoundPage {
    NotFoundPage(path: context.location.path)
  }
}
```

Macros cannot read declarations of another module, so neither side infers the other: the host
names the feature type, and the feature's macro generates `_register(into:under:wrap:)`, which
registers the feature's records into the host's `RouteBuilder<AppRoutes.RouteView>`. The host's
generated `routes()`:

- registers a mount record at `/shop`, under the innermost host layout that wraps the path
- registers the feature below it, with a wrapper that places `ShopRoutes<AppRoutes.RouteView>.RouteView`
  into the host view as one concrete outlet case, such as `case shop(ShopRoutes<AppRoutes.RouteView>.RouteView)`
  in `AppRoutes.RouteView.ShellOutlet`
- builds one tree and returns a route set with `routes.handles.shop`, the mount record, and
  `routes.shop`, the feature's route set in that tree

The feature's route set has a destination factory per route, returning host destinations:

```swift
let routes = try AppRoutes.routes()
let router = routes.router()

let product = try routes.shop.product(id: 7)   // RouteDestination<AppRoutes.RouteView>
try routes.href(to: product)                    // "/shop/products/7"
try router.navigate(to: product)
router.matchedRoutes                            // [shell, shop, shopLayout, product]
router.isActive(routes.handles.shop, options: .descendant)
```

Mounted destinations are host destinations, so `AppRoutes.Link`, `router.href(to:)`, and
`routes.href(to:)` accept them, and a `@Routes(mode: .hash)` host produces `#/shop/products/7`
for the same destination.

### Links inside features

Feature views are generic over `Root`, the host's route view, and never name the host. The host's
generated `Provider`, which `AppRoutes.RouterView` installs, provides two values for them:

- each mounted feature's route set, read with `@Environment(ShopRoutes<Root>.RouteSet.self)`
- the host router as a `RouteNavigator<Root>`, read with `@Environment(RouteNavigator<Root>.self)`

`RouteNavigator` stores the host's concrete `Router` or `HashRouter`; it is not a router protocol.
`RouteLink` reads it to link to any destination of the host tree in the host's mode:

```swift
@View
public struct ProductPage<Root: View> {
  @Environment(ShopRoutes<Root>.RouteSet.self) var shop: ShopRoutes<Root>.RouteSet?
  @Environment(BlogRoutes<Root>.RouteSet.self) var blog: BlogRoutes<Root>.RouteSet?

  let id: Int

  public var body: some View {
    if let shop {
      RouteLink(to: shop.catalog()) { "All products" }
    }
    // Cross-feature: the shop module imports the blog module.
    if let blog, let review = try? blog.post(slug: "review-\(id)") {
      RouteLink(to: review) { "Read the review" }
    }
  }
}
```

A route set is `nil` when the closest host does not mount that feature. The navigator's
`isActive`, `href(to:)`, `navigate(to:)`, and `replace(to:)` behave like the router's.

Both values are environment objects identified by their type, the way ElementaryUI identifies
reactive objects. `ShopRoutes<AppRoutes.RouteView>.RouteSet`, `ShopRoutes<OtherRoutes.RouteView>.RouteSet`,
and a feature that another module also names `ShopRoutes` are three keys, and
`RouteNavigator<AppRoutes.RouteView>` is a different key from every other host's navigator.
A host and its features may share a name: a module that declares a type named `Routes` and
uses the macro writes `@ElementaryRouter.Routes`, as Swift otherwise cannot tell the attribute
from the type.

### Supported shape

- A feature declares `@Route` and `@Layout` like a route set. It has no `mode`, `@NotFound`,
  `@RouteError`, `@Mount`, router, `Provider`, `RouterView`, `Link`, or `routes()`; the host owns
  them. The names `mount` and `wrap` are reserved in features.
- A mount path is static: no `:` parameters and no `*` wildcard. Feature routes may use both.
- The mounted feature owns every URL at and below its path. `@Routes` rejects host routes at or
  below a mount path, host layouts below it, and mounts that overlap another mount, so a host
  and a feature it cannot see can never declare routes that match the same URLs. A host layout at
  exactly the mount path wraps the mount.
- Host layouts that wrap a mount may read `RouteContext` and defaulted queries; a required query
  is rejected, because feature destinations cannot supply it. Feature factories take only the
  feature's own queries, so wrapping host layouts render their query defaults for them.
- The type alias must specialize the feature with the host's `RouteView`, and a host mounts each
  feature type once. Spellings cannot show whether two aliases name one type, so the generated
  `routes()` compares the specialized route set types before registering anything and throws
  `RouteTreeError.duplicateFeature` for `ShopRoutes<RouteView>` mounted again as
  `Shop.ShopRoutes<RouteView>` or through another alias. Features of different modules that share
  a name are different types and mount side by side.
- `RouteContext` values in a feature describe the host tree: `path` includes the mount path, and
  `matchedRoutes` starts with the host's layouts and the mount record.

`RouteBuilder._build()` still checks the final tree, so a manually composed tree that registers
an overlapping route throws `RouteTreeError.duplicateRoute` or `.ambiguousRoute`, and a feature
registered under a mount record of another builder throws `.foreignParent`. Destinations from
another `routes()` call are rejected with `RouteMatchError.foreignRoute`, and a destination of
another host, or of a feature specialized for another host, does not compile.

### Limitations

- Mounting is static. There is no runtime plugin registration and no mount with path parameters.
- Features do not nest: a feature cannot mount another feature.
- A host's own `_routerEnvironmentKey` and `_routeSetEnvironmentKey` are still named after the
  host type, as before feature composition. Two hosts with the same type name, from different
  modules or scopes, must not be nested in one page. Feature route sets and navigators are keyed
  by type and have no such restriction.
- The duplicate-feature check runs when `routes()` builds the tree, not at compile time.
- Features cannot declare their own fallback views; `/shop/missing` renders the host's
  `@NotFound`, and an undecodable feature value renders the host's `@RouteError`.
- Feature views that link must be generic over `Root`. Views without links can stay concrete.

[Examples/FeatureComposition](Examples/FeatureComposition) mounts separate `Shop` and `Blog`
modules into one app.

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

- `AppRoutes.RouteView`: a single typed view tree for all route outputs, with
  a nested outlet enum per layout
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

#### Layout values

Every matched layout receives its own values, decoded from its own match:

- path and wildcard values from the part of the URL the layout's path matches
- `Query<T>` values with the layout's own defaults, even when the leaf route
  declares no such query or declares it with another default
- a `RouteContext` parameter, when declared, with the layout's own `route`,
  `path`, and `params`; `query`, `location`, and the full `matchedRoutes` stack
  are shared by every context of one match

Values are decoded from parent to leaf. The first layout or route whose value
cannot be decoded, such as `/:lang/teams/abc` for `teamID: Int`, renders the
route set's `@RouteError` with that layout's or route's context; its
descendants are not rendered. A required `Query<T>` that only a layout declares
fails the same way when it is missing. Without `@RouteError` or `@NotFound`,
the generated `RouterView` stops with a precondition failure that names the
missing declaration, and `RouteTree` reports `RouterRenderError`.

#### Layout state

The generated `RouteView` is a tree of concrete views: each layout is rendered
once, outside the switch that selects among its direct children. Every layout
gets a nested outlet enum, such as `AppRoutes.RouteView.LanguageLayoutOutlet`,
with one case per direct child, and receives it as the concrete
`Outlet<_RouteOutlet<LanguageLayoutOutlet>>`. ElementaryUI therefore keeps a layout mounted, with its
`@State`, focus, and DOM elements, as long as navigation stays inside the
layout's subtree:

- between sibling routes, such as `/en/teams/7` and `/en/teams/7/members/42`
  under `@Layout("/:lang/teams/:teamID")`
- when only path or query values change, such as `/en/teams/7` to
  `/en/teams/8`; the layout receives the new values
- when a view above `RouterView()` rebuilds its body

Navigating to a route outside the layout's subtree removes the layout, and
returning creates it again with fresh state. `Tests/BrowserAcceptance/LayoutState`
checks these guarantees in a browser.

State that must outlive a layout's subtree, such as stores, sessions, or caches
shared by several branches, should live above `AppRoutes.RouterView()` and be
passed through ElementaryUI's environment:

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

#### Supported layout shapes

A layout must be a non-throwing, non-async `static func` with exactly one
`Outlet<Content>` parameter, where `Content` is its only generic parameter. Every
route and layout parameter needs an argument label, labels must be unique, and
route and layout names must be unique. `@Route` functions cannot be generic or
take an outlet. The names `collection`, `content`, `notFound`, and `routeError`
are reserved by generated code. `@Routes` reports violations at compile time and
generates no code for the offending declaration, so the diagnostic is the only
error for it; code that uses that declaration's generated factory or handle
reports it as missing until the declaration is fixed.

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
- `@Layout` composes nested route UI through `Outlet<Content>`; a layout stays mounted while navigation stays in its subtree, and state shared across branches belongs above the router view.
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
behavior. `RouteLink`, used by mounted features, follows the same rules with the
host's `RouteNavigator`. Without a provided router, or with a destination from another
`routes()` call, the link stays a plain anchor and the browser performs a normal
document navigation to the same href.

`AppRoutes.Provider(routes, router:)` installs a route set and the concrete
`Router<AppRoutes.RouteView>` or `HashRouter<AppRoutes.RouteView>` created by
that route set in ElementaryUI's environment, together with a `RouteNavigator` for
that router and the route set of each mounted feature. `AppRoutes.RouterView` installs
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
- static feature mounts with `@Mount`, with typed feature destinations, `RouteNavigator`, and
  `RouteLink`

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
- [Examples/FeatureComposition](Examples/FeatureComposition): shop and blog feature modules mounted into one host app
