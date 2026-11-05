import ElementaryUI

/// A link to a destination of the closest host route set, for views generic over its content.
///
/// Mounted features use `RouteLink` for links to their own routes and to other mounted features,
/// because their views know the host only as a generic `RouteContent`:
///
/// ```swift
/// @Environment(ShopRoutes<Root>.RouteSet.self) var shop: ShopRoutes<Root>.RouteSet?
///
/// if let shop {
///   RouteLink(to: shop.catalog()) { "Catalog" }
/// }
/// ```
///
/// The link reads the closest `RouteNavigator<RouteContent>`, which the host's generated
/// `Provider` installs, and behaves like a generated route-set link: the anchor's `href` follows the host's
/// routing mode, and eligible clicks navigate on the client when the host router accepts the
/// destination. Without a navigator, the link is a plain anchor with the destination's path href.
@View
public struct RouteLink<RouteContent: View, Content: View> {
  @Environment(RouteNavigator<RouteContent>.self) var navigator: RouteNavigator<RouteContent>?

  let destination: RouteDestination<RouteContent>
  let replace: Bool
  let target: HTMLAttributeValue.Target?
  let content: Content

  /// Creates a link to `destination`.
  public init(
    to destination: RouteDestination<RouteContent>,
    replace: Bool = false,
    target: HTMLAttributeValue.Target? = nil,
    @HTMLBuilder content: () -> Content
  ) {
    self.destination = destination
    self.replace = replace
    self.target = target
    self.content = content()
  }

  public var body: some View {
    if let target {
      a(.href(href), .target(target)) {
        content
      }
      .attributes(.data("router-link", value: "true"), when: usesClientNavigation)
      .onClick { event in
        handleClick(event)
      }
    } else {
      a(.href(href)) {
        content
      }
      .attributes(.data("router-link", value: "true"), when: usesClientNavigation)
      .onClick { event in
        handleClick(event)
      }
    }
  }

  /// The destination href in the host's mode, or its path href without a host navigator.
  var href: String {
    navigator?.linkHref(for: destination) ?? destination.location.href
  }

  private var usesClientNavigation: Bool {
    navigator?.accepts(destination) ?? false
  }

  private func handleClick(_ event: MouseEvent) {
    guard
      event.button == 0,
      !event.altKey,
      !event.ctrlKey,
      !event.metaKey,
      !event.shiftKey,
      target == nil || target?.rawValue == "" || target?.rawValue == "_self",
      let navigator,
      navigator.accepts(destination)
    else {
      return
    }

    do throws(RouteMatchError) {
      try navigator.navigate(to: destination, replace: replace)
    } catch {
      assertionFailure("RouteLink could not navigate to an accepted destination.")
    }
  }
}
