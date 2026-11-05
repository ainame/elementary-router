import ElementaryUI

/// The matched child of one layout in a generated route view.
///
/// `@Routes` generates one conforming enum per layout, such as `AppRoutes.RouteView.ShellOutlet`,
/// with one case per direct child of the layout. `content` switches over the case, so the
/// layout itself is rendered outside that switch and stays mounted while the child changes.
///
/// The conformance is declared on the generated enum itself rather than produced by another
/// macro, so it is emitted like any handwritten conformance.
public protocol _RouteOutletStorage {
  associatedtype Content: View

  /// The view of the matched child.
  @HTMLBuilder var content: Content { get }
}

/// Renders the matched child of a layout, placed by the layout through its `Outlet`.
///
/// Generated layouts receive `Outlet<_RouteOutlet<Storage>>`, a concrete view type, so route
/// rendering needs no type erasure.
@View
public struct _RouteOutlet<Storage: _RouteOutletStorage> {
  /// The matched child.
  public let storage: Storage

  /// Creates the outlet view for a matched child.
  public init(storage: Storage) {
    self.storage = storage
  }

  public var body: some View {
    storage.content
  }
}
