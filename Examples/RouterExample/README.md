# ElementaryRouter Example

This example was scaffolded with:

```sh
npx degit elementary-swift/starter-vite Examples/RouterExample
```

It uses ElementaryUI plus the local `ElementaryRouter` package through a SwiftPM path dependency.

## Run

```sh
npm install
npm run dev
```

## Build

```sh
swift build
npm run build
```

## Routes

- `/`
- `/:lang/profile/:profileId?tab=posts`
- `/docs/*#install`

The example declares routes with `@Routes`. The macro generates `AppRoutes.RouteView`, `AppRoutes.RouteSet`, and a typed destination factory per route, such as `routes.profile(lang: "ja", profileId: 42, tab: "posts")`. The same destination drives `AppRoutes.Link`, the active-link highlight from `router.isActive(_:)`, and the "Open profile 7" button's `router.navigate(to:)`. Destinations with path values can fail to build, so the navigation renders that failure explicitly instead of trapping in a view body.

`/:lang` is declared as a typed `@Layout` route, and `/:lang/profile/:profileId` is rendered through that layout with `Outlet<Content>`.

Fallback policy is declared with `@NotFound` and `@RouteError`, so route fallback selection does not live inside a page view body.

`AppRoutes.RouterView` renders the selected route through the macro-generated typed route view. This keeps the example on upstream ElementaryUI without a vendored `AnyView` spike.

`index.html` includes the temporary Link interception workaround used by 0.0.1:
router anchors are marked with `data-router-link`, and a capture-phase click
handler calls `preventDefault()` for eligible same-origin clicks before the Swift
`onClick` handler performs router navigation.
