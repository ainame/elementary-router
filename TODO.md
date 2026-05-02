# TODO

This library is pre-release. Do not preserve temporary API compatibility when a cleaner final design is available.

1. [x] Close manual `RouteHandle` construction.
   - Make `RouteID` and `RouteHandle` initializers internal.
   - Keep route handles as values returned by `RouteCollection`.
   - Use a distinct error for unknown route handles instead of treating them as missing params.

2. [x] Move from flat matching to nested route matching.
   - Add parent-child route registration.
   - Make `Router.matches` a real parent-to-leaf match stack.
   - Keep `Router.currentMatch` as the leaf convenience.
   - Prepare the model for future layout/outlet rendering.

3. [ ] Decide the real `RouterView` rendering model with ElementaryUI.
   - Problem:
     - Each route builder can return a different concrete `View` type.
     - Swift's `some View` model wants the return type to be known statically, but routing chooses the route at runtime from the current URL.
     - Therefore `RouterView` needs a way to hold, switch, and mount heterogeneous route views without forcing users to put fallback/error decisions inside each page's `body`.
   - ElementaryUI API decision:
     - Investigate how ElementaryUI internally represents and mounts views today.
     - Decide the smallest public API ElementaryUI should expose for runtime view switching.
     - Candidate shapes include `AnyView`, `AnyRoutableView`, a public mount/render closure, or a lower-level node-producing abstraction.
     - The API should be general enough for router use, but not leak router-specific concepts into ElementaryUI.
   - Router API decision:
     - Keep route builders ergonomic:
       ```swift
       routes.route("/:lang/profile/:profileId") { context throws in
         ProfilePage(
           lang: try context.params.require("lang"),
           profileID: try context.params.require("profileId", Int.self)
         )
       }
       ```
     - Avoid making users manually erase every route view.
     - Avoid putting not-found, param parsing fallback, or route-level error branching inside page `body`.
     - Decide whether route builders store an erased render value immediately, or store a typed builder that is erased only when the route tree is frozen.
   - Nested rendering decision:
     - `Router.matches` is already intended to be a parent-to-leaf stack.
     - Decide how matched parent layouts render children.
     - Likely model: parent route renders a layout, and an `Outlet` placeholder renders the next child match.
     - Confirm whether `Outlet` should be an ElementaryRouter view, an environment value, or an explicit value passed through `RouteContext`.
     - Decide index-route behavior under a layout route.
   - Error and not-found decision:
     - Route matching failure should render a configured not-found view, not a branch inside a page body.
     - Param/query decode failures thrown from route builders should be caught by the router.
     - Prefer nearest route-level error view first, then router-level error view.
     - Decide how errors in parent layout routes affect child outlet rendering.
   - Lifecycle decision:
     - Decide whether route views are recreated on every navigation or whether the router keeps mounted instances for stable parent layouts.
     - Decide how much identity ElementaryUI needs from route matches to preserve state.
     - This affects future loaders, pending states, and animation support.
   - Implementation steps:
     - Write a small design note or spike showing the minimal ElementaryUI public API needed by `RouterView`.
     - Update `RouterView` from placeholder behavior to the chosen erased rendering model.
     - Add tests for rendering the current route, switching route views, nested outlet rendering, not-found rendering, and route-level error rendering.
     - Update `Examples/RouterExample` to demonstrate nested layout routes and route-level error/not-found handling.

4. [ ] Complete `Link` navigation semantics.
   - Intercept same-origin, left-click, no-modifier, no-target navigation.
   - Call `preventDefault` once ElementaryUI exposes the required public event API.
   - Keep modifier clicks, external URLs, downloads, and target behavior browser-native.
   - Always generate a meaningful `href`.
   - Add active matching options for exact, descendant, params, query, and hash matching.

5. [ ] Add navigation lifecycle features after nested routing is stable.
   - Add redirect / before-load policy.
   - Add pending and route-level error state.
   - Evaluate loaders and preload only after the render stack is real.
   - Evaluate query schema and validation after `RouteParameters` settles.
   - Evaluate navigation blockers after browser event interception is complete.

6. [ ] Harden Embedded Swift and WASM support.
   - Keep production code free of `Foundation` imports.
   - Add CI checks that build the package and the Vite example.
   - Add tests around percent encoding, query parsing, and JavaScriptKit boundary behavior.
   - Keep browser-specific code behind history adapters.

7. [ ] Improve documentation and examples.
   - Update `README.md` to use `ElementaryRouter` naming everywhere.
   - Document `RouteCollection`, `RouteScope`, `RouteHandle`, `RouteParameters`, and `RouterProvider`.
   - Expand `Examples/RouterExample` to show nested routes, not-found handling, query params, and programmatic navigation.
   - Document current limitations around `RouterView` and `Link` until the ElementaryUI APIs exist.
