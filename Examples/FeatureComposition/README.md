# Feature composition example

Two feature modules, `Shop` and `Blog`, mounted into one host app, `WebApp`, with ordinary
imports. The app has a single route tree, a single path-mode router, and typed destinations
everywhere.

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

## Modules

- `Blog` declares `BlogRoutes<Root: View>` with `/` and `/:slug`.
- `Shop` declares `ShopRoutes<Root: View>` with a shop layout, `/`, and `/products/:id`. It
  imports `Blog` to link each product to its review.
- `WebApp` declares the host `AppRoutes` with its shell layout, home page, `@NotFound`, and
  `@RouteError`, and mounts both features:

```swift
@Mount("/shop")
typealias Shop = ShopRoutes<RouteView>

@Mount("/blog")
typealias Blog = BlogRoutes<RouteView>
```

## What it shows

- One tree: `/shop/products/1` matches `[shell, shop, shopLayout, product]`, from the host
  shell, through the mount record, to the feature leaf.
- Typed outlets: the shell's outlet stores `ShopRoutes<AppRoutes.RouteView>.RouteView` as one
  concrete case, so the shell stays mounted between the shop and the blog, and the shop
  layout keeps its note while you move between the catalog and a product.
- Feature-internal links: shop and blog views are generic over `Root`. They read their route
  set with `@Environment(ShopRoutes<Root>.RouteSet.self)` and link with
  `RouteLink(to: shop.product(id: 1))`.
- Cross-feature links: the product page reads `BlogRoutes<Root>.RouteSet.self` and
  links to `blog.post(slug:)`, a destination in the same host tree.
- Host links: the shell uses `AppRoutes.Link(to: routes.shop.catalog())`, because mounted
  destinations are `RouteDestination<AppRoutes.RouteView>` like the host's own.
- Host policy: `/shop/missing` renders the host's `@NotFound`, and `/shop/products/abc`
  renders its `@RouteError`.

`Tests/BrowserAcceptance/FeatureComposition` mounts the same `Shop` and `Blog` modules in a
path-mode host and a hash-mode host and checks these behaviors in a browser.

`index.html` includes the temporary Link interception workaround; see the root README.
