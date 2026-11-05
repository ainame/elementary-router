# Layout state browser acceptance

A small app that checks, in a real browser DOM, how long route layouts and their `@State`
stay mounted. It builds against the local package path and upstream `elementary-ui`, like the
examples.

`FixtureRoutes` declares a root `shell` layout and a `team` layout at `/teams/:teamID`. Both
layouts own an `<input>` bound to `@State`; the team layout also owns a counter. The team layout
wraps two sibling routes, `/teams/:teamID` and `/teams/:teamID/members/:memberID`. `/settings`
is outside the team layout. `AppRoot` can rebuild the body that contains `FixtureRoutes.RouterView()`.

The scenario in `acceptance.ts` clicks the generated links and calls `history.back()`, and
checks element identity with `===` as well as the `@State` values echoed into the DOM:

1. Navigating between sibling child routes keeps the team layout element, its input element,
   its input value, and its counter, and keeps the shell layout.
2. Rebuilding the parent of `RouterView()` keeps the rendered route, every layout, and the
   router: links still navigate afterwards.
3. Changing `teamID` stays in the team branch: the layout is kept and receives the new value.
4. Leaving the team branch for `/settings` removes the team layout. Returning with browser back
   creates a new team layout with empty state, while the shell layout is kept.

## Running

```sh
cd Tests/BrowserAcceptance/LayoutState
npm install
npm run build
npm run preview
```

Open `http://localhost:4173/?acceptance` in a browser. The scenario starts once the app has
mounted and appends `#acceptance-result`, with `data-status="pass"` or `data-status="fail"`, and
sets `document.title` to `PASS` or `FAIL: <step>: <reason>`. The same report is logged to the
console. `npm run dev` with `http://localhost:5173/?acceptance` works as well.

Headless, for example with Chrome:

```sh
chrome --headless=new --virtual-time-budget=20000 --dump-dom \
  "http://localhost:4173/?acceptance" | grep -A12 'id="acceptance-result"'
```

or with Playwright, without adding it to this package:

```sh
npx playwright@latest screenshot --wait-for-selector '#acceptance-result' \
  "http://localhost:4173/?acceptance" result.png
```

Without `?acceptance`, the app can be driven by hand; `window.runLayoutStateAcceptance()` runs
the scenario from the browser console and resolves to `true` when it passes.
