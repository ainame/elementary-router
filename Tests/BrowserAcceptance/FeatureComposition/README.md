# Feature composition browser acceptance

A small app that checks mounted features in a real browser DOM. It builds against the local
package path, upstream `elementary-ui`, and the `Shop` and `Blog` feature modules of
`Examples/FeatureComposition`.

The path-mode host `Routes` and the hash-mode host `HashHost` declare the same shell layout and
mount the shop and blog with `@Mount("/shop")` and `@Mount("/blog")`. They also mount the local
`GuideAlpha` and `GuideBeta` modules at `/alpha` and `/beta`; both modules declare a feature named
`Routes`, the same name as the path-mode host, so this module and the guide modules write
`@ElementaryRouter.Routes`. `?mode=hash` selects `HashHost`. The shell is
shared by both hosts: it is generic over the host's route view and links into the features with
`RouteLink`, as feature views do.

The scenario in `acceptance.ts` clicks generated links and calls `history.back()`. Every link
must be a client-navigation link whose `href` is the path (`/shop/products/1`) in path mode and
the fragment (`#/shop/products/1`) in hash mode. It checks:

1. A host shell link enters the shop; the shell layout, its input, and its value are kept.
2. Feature-internal links between the catalog and products, with and without a query, keep the
   shop layout element and its `@State` value.
3. The product page's cross-feature link to its blog review removes the shop layout and keeps
   the shell.
4. A blog-internal link stays in the blog.
5. Browser back re-enters the shop with a new shop layout and empty state, while the shell is
   kept.
6. In path mode, the home page of the host named `Routes` reads the host's route set by its key
   and the alpha guide's route set by its type, and links into both guides with the right hrefs.
7. The two guides, both named `Routes`, each read their own route set: their links point into
   `/alpha` and `/beta` respectively, in both modes.

## Running

```sh
cd Tests/BrowserAcceptance/FeatureComposition
npm install
npm run build
npm run preview
```

Open both `http://localhost:4173/?acceptance` and
`http://localhost:4173/?acceptance&mode=hash`. Each run appends `#acceptance-result`, with
`data-status="pass"` or `data-status="fail"`, and sets `document.title` to `PASS` or
`FAIL: <step>: <reason>`. The same report is logged to the console.

Headless, for example with Chrome:

```sh
for query in "acceptance" "acceptance&mode=hash"; do
  chrome --headless=new --virtual-time-budget=20000 --dump-dom \
    "http://localhost:4173/?$query" | grep -A10 'id="acceptance-result"'
done
```

Without `?acceptance`, the app can be driven by hand;
`window.runFeatureCompositionAcceptance()` runs the scenario from the browser console, starting
from the home page.
