import Blog
import ElementaryRouter
import ElementaryUI

/// The shop's own chrome, inside the host's shell. Its draft survives navigation between shop
/// routes and is reset when navigation leaves the shop.
@View
public struct ShopLayout<Root: View, Content: View> {
  @Environment(ShopRoutes<Root>.RouteSet.self) var shop: ShopRoutes<Root>.RouteSet?
  @Environment(RouteNavigator<Root>.self) var navigator: RouteNavigator<Root>?
  @State var draft = ""

  let outlet: Outlet<Content>

  public var body: some View {
    section(.id("shop-layout")) {
      header {
        h2 { "Shop" }
        if let shop {
          span(.id("link-shop-catalog")) {
            RouteLink(to: shop.catalog()) { "All products" }
          }
          // The feature's own layout handle, checked against the host router.
          if navigator?.isActive(shop.handles.product) ?? false {
            span(.id("shop-viewing-product")) { " (viewing a product)" }
          }
        }
        label {
          " Shopping note "
          input(.id("shop-draft"), .type(.text)).bindValue($draft)
        }
        span(.id("shop-echo")) { draft }
      }
      outlet
    }
  }
}

@View
public struct CatalogPage<Root: View> {
  @Environment(ShopRoutes<Root>.RouteSet.self) var shop: ShopRoutes<Root>.RouteSet?

  let sort: String

  public var body: some View {
    article(.id("page"), .data("page", value: "shop-catalog")) {
      p { "Sorted by \(sort)" }
      if let shop {
        ul {
          ForEach(Product.all, key: { $0.id }) { product in
            li(.id("link-product-\(product.id)")) {
              ProductLink(shop: shop, product: product)
            }
          }
        }
      }
    }
  }
}

@View
public struct ProductPage<Root: View> {
  @Environment(ShopRoutes<Root>.RouteSet.self) var shop: ShopRoutes<Root>.RouteSet?
  // The blog's route set in the same host, when the host mounts the blog.
  @Environment(BlogRoutes<Root>.RouteSet.self) var blog: BlogRoutes<Root>.RouteSet?

  let id: Int

  public var body: some View {
    article(.id("page"), .data("page", value: "shop-product"), .data("product", value: "\(id)")) {
      if let product = Product.withID(id) {
        h3 { product.name }
        if let blog {
          // A cross-feature link: a blog destination in the host tree, typed by the same `Root`.
          switch reviewDestination(blog: blog, product: product) {
          case .success(let review):
            span(.id("link-review")) {
              RouteLink(to: review) { "Read the review" }
            }
          case .failure:
            span { "Review unavailable" }
          }
        }
      } else {
        h3 { "Unknown product \(id)" }
      }
      if let shop {
        span(.id("link-back")) {
          RouteLink(to: shop.catalog(sort: "price")) { "Back to the catalog" }
        }
      }
    }
  }

  private func reviewDestination(
    blog: BlogRoutes<Root>.RouteSet,
    product: Product
  ) -> Result<RouteDestination<Root>, RouteMatchError> {
    Result { () throws(RouteMatchError) in try blog.post(slug: product.reviewSlug) }
  }
}

/// A link to one product; product destinations have a path value, so they can fail to build.
@View
struct ProductLink<Root: View> {
  let shop: ShopRoutes<Root>.RouteSet
  let product: Product

  var body: some View {
    switch destination {
    case .success(let destination):
      RouteLink(to: destination) { product.name }
    case .failure:
      span { product.name }
    }
  }

  private var destination: Result<RouteDestination<Root>, RouteMatchError> {
    Result { () throws(RouteMatchError) in try shop.product(id: product.id) }
  }
}
