import ElementaryUI

@View
struct NotFoundPanel {
  let title: String
  let message: String

  var body: some View {
    section(.style(panelStyle)) {
      h2(.style(sectionTitleStyle)) { title }
      p(.style(mutedTextStyle)) { message }
    }
  }
}
