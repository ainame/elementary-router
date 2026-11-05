import ElementaryRouter
import ElementaryUI

/// Routes whose layouts own view state, so the browser run can observe their mount lifetime.
///
/// `team` wraps two sibling routes, `teamIndex` and `member`. `settings` is outside the team
/// layout, so navigating there leaves the team branch.
@Routes
struct FixtureRoutes {
  @Layout("/")
  static func shell<Content: View>(outlet: Outlet<Content>) -> ShellLayout<Content> {
    ShellLayout(outlet: outlet)
  }

  @Layout("/teams/:teamID")
  static func team<Content: View>(
    teamID: Int,
    view: Query<String> = Query("list"),
    outlet: Outlet<Content>
  ) -> TeamLayout<Content> {
    TeamLayout(teamID: teamID, view: view.value, outlet: outlet)
  }

  @Route("/")
  static func home() -> FixturePage {
    FixturePage(name: "home")
  }

  @Route("/teams/:teamID")
  static func teamIndex(teamID: Int) -> FixturePage {
    FixturePage(name: "team-index", detail: "team \(teamID)")
  }

  @Route("/teams/:teamID/members/:memberID")
  static func member(
    teamID: Int,
    memberID: Int,
    view: Query<String> = Query("card")
  ) -> FixturePage {
    FixturePage(name: "member", detail: "team \(teamID) member \(memberID) view \(view.value)")
  }

  @Route("/settings")
  static func settings() -> FixturePage {
    FixturePage(name: "settings")
  }

  @NotFound
  static func notFound(context: RouteNotFoundContext) -> FixturePage {
    FixturePage(name: "not-found", detail: context.location.path)
  }

  @RouteError
  static func routeError(context: RouteErrorContext) -> FixturePage {
    FixturePage(name: "route-error", detail: context.routeContext.path)
  }
}
