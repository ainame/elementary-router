import ElementaryRouter
import ElementaryUI
import NewsFeature

/// A public feature with a layout, compiled in its own module. It imports `NewsFeature` for
/// cross-feature links.
@Routes
public struct StoreRoutes<Root: View> {
  @Layout("/")
  public static func frame<Content: View>(
    context: RouteContext,
    outlet: Outlet<Content>
  ) -> StoreFrame<Root, Content> {
    StoreFrame(outlet: outlet)
  }

  @Route("/")
  public static func catalog(page: Query<Int> = Query(1)) -> EmptyHTML {
    EmptyHTML()
  }

  @Route("/products/:sku")
  public static func product(sku: String) -> StoreProduct<Root> {
    StoreProduct(sku: sku)
  }
}

@View
public struct StoreFrame<Root: View, Content: View> {
  @Environment(StoreRoutes<Root>.RouteSet.self) var store: StoreRoutes<Root>.RouteSet?
  @Environment(RouteNavigator<Root>.self) var navigator: RouteNavigator<Root>?

  let outlet: Outlet<Content>

  public var body: some View {
    if let store {
      RouteLink(to: store.catalog(page: 2), replace: true) { "Catalog" }
      if navigator?.isActive(store.handles.frame, options: .descendant) ?? false {
        "In the store"
      }
    }
    outlet
  }
}

@View
public struct StoreProduct<Root: View> {
  @Environment(StoreRoutes<Root>.RouteSet.self) var store: StoreRoutes<Root>.RouteSet?
  @Environment(NewsRoutes<Root>.RouteSet.self) var news: NewsRoutes<Root>.RouteSet?

  let sku: String

  public var body: some View {
    if let store {
      RouteLink(to: store.catalog()) { "Back" }
    }
    // A feature view builds destinations of another feature in the same host tree.
    if let news, let review = try? news.article(slug: "review-" + sku) {
      RouteLink(to: review, target: .blank) { "Review" }
    }
  }
}

/// A destination factory used generically, as feature views do.
public func storeProductDestination<Root: View>(
  _ store: StoreRoutes<Root>.RouteSet,
  sku: String
) throws(RouteMatchError) -> RouteDestination<Root> {
  try store.product(sku: sku)
}
