# TODO

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
   - Coordinate the needed public type-erased view/mount API.
   - Remove or mark placeholder rendering APIs as experimental until this is solved.

4. [ ] Complete `Link` navigation semantics.
   - Prevent default browser navigation for intercepted same-origin clicks.
   - Add active matching options.
   - Keep modifier clicks, external URLs, and target behavior browser-native.

5. [ ] Add navigation lifecycle features after nested routing is stable.
   - Add redirect / before-load policy.
   - Add pending and route-level error state.
   - Evaluate loaders, preload, blockers, and query schema after the core tree is stable.
