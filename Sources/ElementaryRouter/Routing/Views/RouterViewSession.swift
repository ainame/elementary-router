/// Lazily creates and owns the route set and router of a generated `RouterView()`.
///
/// ElementaryUI evaluates a `@State` initial value every time the owning view value is built,
/// and keeps only the first one once the view is mounted. Creating a router there would start a
/// history listener for every rebuilt parent body. A session is cheap to create and builds its
/// route set and router only when it is first read, so the session kept in the mounted view's
/// state is the only one that ever creates them. The router, and with it the history listener,
/// is released with the session when the view is unmounted.
public final class _RouterViewSession<Routes, RouterType: AnyObject> {
  private let make: () -> (routes: Routes, router: RouterType)
  private var created: (routes: Routes, router: RouterType)?

  /// Creates a session that calls `make` once, on first access.
  public init(_ make: @escaping () -> (routes: Routes, router: RouterType)) {
    self.make = make
  }

  /// `true` once the route set and router have been created.
  public var isStarted: Bool {
    created != nil
  }

  /// The session's route set, creating it and its router on first access.
  public var routes: Routes {
    start().routes
  }

  /// The session's router, creating it and its route set on first access.
  public var router: RouterType {
    start().router
  }

  private func start() -> (routes: Routes, router: RouterType) {
    if let created {
      return created
    }
    let value = make()
    created = value
    return value
  }
}
