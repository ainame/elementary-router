import ElementaryUI

/// Placeholder content used by generated layout routes.
///
/// Layout renderers place `Outlet` where the currently matched child route should appear.
@View
public struct Outlet<Content: View> {
  let content: Content

  /// Wraps the child route content for insertion into a layout.
  public init(_ content: Content) {
    self.content = content
  }

  /// The wrapped child content.
  public var body: some View {
    content
  }
}
