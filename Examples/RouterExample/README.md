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
- `/:lang/profile/:profileId?tab=posts`
- `/docs/*#install`

The example registers routes with an `ExampleRoutes` instance and keeps the `RouteHandle` values for `Link` and programmatic navigation.

Fallback policy is registered on `RouteCollection` with `notFound` and `error`, so route fallback selection does not live inside a view body.

`RouterView()` is mounted in the app, but route view type erasure is still blocked by ElementaryUI's current public API. Until ElementaryUI exposes a public type-erased mount/view API, `RouterView` can resolve the active route and invoke the route pipeline, but cannot yet mount the selected route view.
