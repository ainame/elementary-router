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

The app keeps task state in a shared `TodoStore`, places it in the ElementaryUI
environment, and renders each route through the macro-generated typed route
view.
