# Repository Guidelines

## Project Direction

- This repository is `elementary-router`; the Swift package product and module are `ElementaryRouter`.
- Do not use the old names `elementary-ui-router` or `ElementaryUIRouter` in new code, docs, examples, or generated files.
- Version `0.0.1` is the first releasable API shape, but the library is still pre-1.0 and has no compatibility contract. Prefer the best final API shape over preserving temporary APIs.
- The router is a URL state router for ElementaryUI running on Swift/WASM. Form actions, non-GET mutations, server functions, SSR, hydration, and loader caching are out of scope until the route tree and rendering model are stable.

## Implementation Constraints

- Production source must not import `Foundation`.
- Keep Embedded Swift compatibility in mind. Avoid APIs that are known to be fragile there, including unnecessary existential errors, `weak` references in core types, and Foundation-backed URL parsing.
- Use `ElementaryUI`, `Reactivity`, and `JavaScriptKit` directly. Do not depend on ElementaryUI internal browser interop APIs.
- Browser integration should remain adapter-based:
  - `BrowserHistory` for JavaScriptKit-backed browser history.
  - `MemoryHistory` for tests.
  - `HashHistory` for static hosting fallback.
- Use `RouteParameters` for path params and query params. It supports dictionary literals and tuple-list initialization.
- `RouteHandle` and `RouteID` should be created by route registration only. Do not add public initializers unless the route identity model is redesigned.
- `Router.matches` is the parent-to-leaf match stack. `Router.currentMatch` is only a leaf convenience.
- Route rendering fallbacks must not live inside a view's `body`. Keep not-found and error policy on route/router configuration.

## Known Design Blockers

- `RouterView` should stay on the typed `@Routes` / generated `RouteView` model. Do not reintroduce a vendored ElementaryUI `AnyView` spike for route rendering.
- `Link` cannot fully intercept client navigation until ElementaryUI exposes enough event API to call `preventDefault` for eligible clicks.
- The current app-level workaround is to have `Link` emit `data-router-link="true"` and add a capture-phase HTML script that calls `preventDefault()` for eligible same-origin clicks before ElementaryUI's Swift `onClick` handler runs. Keep this documented as a workaround, not the final library contract.
- Nested route rendering is implemented through typed `@Layout` and `Outlet<Content>`; avoid runtime-erased outlet designs unless the route identity model is redesigned.

## Release Hygiene

- Keep the root `README.md` focused on the public 0.0.1 API, installation, known blockers, and example usage.
- Do not commit vendored ElementaryUI experiments, temporary TODO files, generated build output, `node_modules`, or Vite `dist`.
- `Examples/RouterExample` should build against the local package path and upstream `elementary-ui`.
- If the Link interception workaround changes, update both `README.md` and `Examples/RouterExample/index.html`.

## Style

- Use the repository `.swift-format` configuration.
- Format Swift with 2-space indentation.
- Keep method-call closing parentheses visually symmetrical with multiline arguments, matching the current formatter config.
- Do not run `swift-format` against Markdown files.
- Prefer direct, Swifty APIs over compatibility aliases. Avoid empty typealiases.

## Validation

Run these before handing off Swift changes:

```sh
swift-format lint --configuration .swift-format Package.swift Sources Tests Examples/RouterExample/Package.swift Examples/RouterExample/Sources --recursive --parallel
swift test
cd Examples/RouterExample && swift build
cd Examples/RouterExample && npm run build
```

For Markdown-only changes, Swift builds are not required unless the documentation changes executable snippets or package names.

## External Research

- When inspecting external repositories, use `ghq get` and read the local checkout.
- TanStack Router is the main design reference for route tree and route handle concepts, but Swift APIs should not copy TypeScript-specific patterns when they reduce testability or extensibility.

## PRs

- Create pull requests as drafts.
- Do not assign reviewers yourself.
