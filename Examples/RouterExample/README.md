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
- `/:lang/profile/:profileId`
- `/docs/*#install`

The example declares routes with `@Routes`. The macro generates `AppRoutes.RouteView`, `AppRoutes.RouteSet`, and route handles for `Link` and programmatic navigation.

`/:lang` is declared as a typed `@Layout` route, and `/:lang/profile/:profileId` is rendered through that layout with `Outlet<Content>`.

Fallback policy is declared with `@NotFound` and `@RouteError`, so route fallback selection does not live inside a page view body.

`AppRoutes.RouterView` renders the selected route through the macro-generated typed route view. This keeps the example on upstream ElementaryUI without a vendored `AnyView` spike.

`index.html` includes the temporary Link interception workaround used by 0.0.1:
router anchors are marked with `data-router-link`, and a capture-phase click
handler calls `preventDefault()` for eligible same-origin clicks before the Swift
`onClick` handler performs router navigation.
