import ElementaryRouter
import ElementaryUI

/// The shop feature. A host mounts it with `@Mount("/shop") typealias Shop = ShopRoutes<RouteView>`.
///
/// The shop layout wraps the catalog and product routes, so it stays mounted, with its `@State`,
/// while navigation stays inside the shop.
@Routes
public struct ShopRoutes<Root: View> {
  @Layout("/")
  public static func shopLayout<Content: View>(outlet: Outlet<Content>) -> ShopLayout<Root, Content> {
    ShopLayout(outlet: outlet)
  }

  @Route("/")
  public static func catalog(sort: Query<String> = Query("name")) -> CatalogPage<Root> {
    CatalogPage(sort: sort.value)
  }

  @Route("/products/:id")
  public static func product(id: Int) -> ProductPage<Root> {
    ProductPage(id: id)
  }
}

/// A product, with the slug of the blog post that reviews it.
public struct Product: Sendable {
  public let id: Int
  public let name: String
  public let reviewSlug: String

  public static let all: [Product] = [
    Product(id: 1, name: "Cast-iron teapot", reviewSlug: "teapot-review"),
    Product(id: 2, name: "Stoneware mug", reviewSlug: "mug-review"),
  ]

  public static func withID(_ id: Int) -> Product? {
    all.first { $0.id == id }
  }
}
