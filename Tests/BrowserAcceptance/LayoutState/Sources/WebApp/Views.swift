import ElementaryRouter
import ElementaryUI

@main
struct App {
  static func main() {
    let app = Application(AppRoot())
    app.mount(in: .body)
  }
}

/// Rebuilds its body on demand, which rebuilds the `RouterView()` value it contains.
@View
struct AppRoot {
  @State var rebuilds = 0

  var body: some View {
    div {
      button(.id("rebuild-parent"), .type(.button)) { "Rebuild parent" }
        .onClick { rebuilds += 1 }
      span(.id("parent-rebuilds")) { "\(rebuilds)" }
      FixtureRoutes.RouterView()
    }
  }
}

@View
struct ShellLayout<Content: View> {
  @Environment(FixtureRoutes._routeSetEnvironmentKey) var routes
  @State var draft = ""

  let outlet: Outlet<Content>

  var body: some View {
    div(.id("shell-layout")) {
      label {
        "Shell draft "
        input(.id("shell-draft"), .type(.text)).bindValue($draft)
      }
      span(.id("shell-echo")) { draft }

      if let routes {
        FixtureNavigation(routes: routes)
      }

      main {
        outlet
      }
    }
  }
}

@View
struct FixtureNavigation {
  let routes: FixtureRoutes.RouteSet

  var body: some View {
    // The acceptance script clicks the anchor inside each identified span.
    nav {
      span(.id("link-home")) {
        FixtureRoutes.Link(to: routes.home()) { "Home" }
      }
      span(.id("link-settings")) {
        FixtureRoutes.Link(to: routes.settings()) { "Settings" }
      }
      switch teamLinks {
      case .success(let links):
        span(.id("link-team-index")) {
          FixtureRoutes.Link(to: links.index) { "Team 7" }
        }
        span(.id("link-member")) {
          FixtureRoutes.Link(to: links.member) { "Member 42" }
        }
        span(.id("link-other-team")) {
          FixtureRoutes.Link(to: links.otherTeam) { "Team 8" }
        }
      case .failure:
        span(.id("link-error")) { "Team links unavailable" }
      }
    }
  }

  private var teamLinks: Result<TeamLinks, RouteMatchError> {
    Result { () throws(RouteMatchError) in
      TeamLinks(
        index: try routes.teamIndex(teamID: 7),
        member: try routes.member(teamID: 7, memberID: 42),
        otherTeam: try routes.teamIndex(teamID: 8)
      )
    }
  }
}

struct TeamLinks {
  let index: RouteDestination<FixtureRoutes.RouteView>
  let member: RouteDestination<FixtureRoutes.RouteView>
  let otherTeam: RouteDestination<FixtureRoutes.RouteView>
}

/// A layout that owns an input value and a counter in `@State`.
@View
struct TeamLayout<Content: View> {
  @State var draft = ""
  @State var count = 0

  let teamID: Int
  let view: String
  let outlet: Outlet<Content>

  var body: some View {
    section(.id("team-layout"), .data("team-id", value: "\(teamID)"), .data("view", value: view)) {
      label {
        "Team draft "
        input(.id("team-draft"), .type(.text)).bindValue($draft)
      }
      span(.id("team-echo")) { draft }
      button(.id("team-count"), .type(.button)) { "Count \(count)" }
        .onClick { count += 1 }
      outlet
    }
  }
}

@View
struct FixturePage {
  let name: String
  var detail: String = ""

  var body: some View {
    article(.id("page"), .data("page", value: name)) {
      h1 { name }
      p(.id("page-detail")) { detail }
    }
  }
}
