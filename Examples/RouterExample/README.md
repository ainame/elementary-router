# ElementaryUI Router Example

This example was scaffolded with:

```sh
npx degit elementary-swift/starter-vite Examples/RouterExample
```

It uses ElementaryUI plus the local `ElementaryUIRouter` package through a SwiftPM path dependency.

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

`RouterView()` is mounted in the app, but route view type erasure is still blocked by ElementaryUI's current public API. Until ElementaryUI exposes a public type-erased mount/view API, this example renders the active route through `router.currentMatch` as a small compatibility layer.
