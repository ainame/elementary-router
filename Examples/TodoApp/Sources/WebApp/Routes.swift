import ElementaryRouter
import ElementaryUI

@Routes
struct AppRoutes {
  @Route("/")
  static func allTasks() -> TodoListPage {
    TodoListPage(filter: .all)
  }

  @Route("/active")
  static func activeTasks() -> TodoListPage {
    TodoListPage(filter: .active)
  }

  @Route("/completed")
  static func completedTasks() -> TodoListPage {
    TodoListPage(filter: .completed)
  }

  @Route("/stats")
  static func stats() -> StatsPage {
    StatsPage()
  }

  @Route("/todo/:todoID")
  static func todoDetail(todoID: Int) -> TodoDetailPage {
    TodoDetailPage(todoID: todoID)
  }

  @NotFound
  static func notFound(context: RouteNotFoundContext) -> NotFoundPage {
    NotFoundPage(path: context.location.path)
  }

  @RouteError
  static func routeError(context: RouteErrorContext) -> InvalidRoutePage {
    InvalidRoutePage(error: context.error)
  }
}
