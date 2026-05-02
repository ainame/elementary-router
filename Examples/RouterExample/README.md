# ElementaryUI Router Example

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

Fallback policy is declared with `@NotFound` and `@RouteError`, so route fallback selection does not live inside a page view body.

`RouterView(router)` renders the selected route through the macro-generated typed route view. This keeps the example on upstream ElementaryUI without a vendored `AnyView` spike.
