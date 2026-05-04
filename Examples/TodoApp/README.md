# ElementaryRouter Todo App

A small task manager that demonstrates `ElementaryRouter` in a more realistic
Swift/WASM app.

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

- `/`: all tasks
- `/active`: active tasks
- `/completed`: completed tasks
- `/stats`: task metrics
- `/todo/:todoID`: task detail

The app keeps task state in `AppRoot`, places it in the ElementaryUI
environment above `AppRoutes.RouterView()`, and renders each route through the
macro-generated typed route view. The root route layout reads `TodoStore` from
the environment instead of owning it, so navigation does not reset task state.
