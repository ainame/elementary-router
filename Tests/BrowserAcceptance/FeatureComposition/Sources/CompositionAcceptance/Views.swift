import Blog
import ElementaryRouter
import ElementaryUI
import GuideAlpha
import GuideBeta
import Shop

#if canImport(JavaScriptKit) && arch(wasm32)
  import JavaScriptKit
#endif

@main
struct App {
  static func main() {
    if usesHashMode {
      let app = Application(HashHost.RouterView())
      app.mount(in: .body)
    } else {
      let app = Application(Routes.RouterView())
      app.mount(in: .body)
    }
  }

  /// `?mode=hash` selects the hash-mode host.
  static var usesHashMode: Bool {
    #if canImport(JavaScriptKit) && arch(wasm32)
      let search = JSObject.global.location.search.string ?? ""
      return search.dropFirst().split(separator: "&").contains("mode=hash")
    #else
      return false
    #endif
  }
}

/// The host shell, shared by both hosts: it only knows the host's route view type, so it links
/// into the features through their route sets and `RouteLink`, like feature views do.
@View
struct AcceptanceShell<Root: View, Content: View> {
  @Environment(ShopRoutes<Root>.RouteSet.self) var shop: ShopRoutes<Root>.RouteSet?
  @Environment(BlogRoutes<Root>.RouteSet.self) var blog: BlogRoutes<Root>.RouteSet?
  @Environment(RouteNavigator<Root>.self) var navigator: RouteNavigator<Root>?
  // Two features named `Routes` from two modules: each is its own environment value.
  @Environment(GuideAlpha.Routes<Root>.RouteSet.self) var alpha: GuideAlpha.Routes<Root>.RouteSet?
  @Environment(GuideBeta.Routes<Root>.RouteSet.self) var beta: GuideBeta.Routes<Root>.RouteSet?
  @State var draft = ""

  let outlet: Outlet<Content>

  var body: some View {
    div(.id("acceptance-shell")) {
      label {
        "Shell draft "
        input(.id("shell-draft"), .type(.text)).bindValue($draft)
      }
      span(.id("shell-echo")) { draft }
      nav {
        if let shop {
          span(
            .id("link-shop"),
            .data("active", value: "\(navigator?.isActive(shop.handles.shopLayout, options: .descendant) ?? false)")
          ) {
            RouteLink(to: shop.catalog()) { "Shop" }
          }
        }
        if let blog {
          span(.id("link-blog")) {
            RouteLink(to: blog.posts()) { "Blog" }
          }
        }
        if let alpha {
          span(.id("link-alpha")) {
            RouteLink(to: alpha.index()) { "Alpha" }
          }
        }
        if let beta {
          span(.id("link-beta")) {
            RouteLink(to: beta.index()) { "Beta" }
          }
        }
      }
      main {
        outlet
      }
    }
  }
}

@View
struct AcceptancePage {
  let name: String
  var detail: String = ""

  var body: some View {
    article(.id("page"), .data("page", value: name)) {
      h1 { name }
      p(.id("page-detail")) { detail }
    }
  }
}
