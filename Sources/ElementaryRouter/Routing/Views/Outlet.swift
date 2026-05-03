import ElementaryUI

@View
public struct Outlet<Content: View> {
  let content: Content

  public init(_ content: Content) {
    self.content = content
  }

  public var body: some View {
    content
  }
}
