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

Navigation uses typed destinations from the generated route set: the filter
links use non-throwing factories such as `routes.activeTasks()`, task rows link
to `routes.todoDetail(todoID:)`, and deleting a task from its detail page calls
`router.replace(to: routes.allTasks())` so going back does not reopen it.
