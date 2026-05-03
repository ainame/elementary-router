import ElementaryUI

@View
struct StatsPage {
  @Environment(TodoStore.self) var store

  var body: some View {
    section(.style(panelStyle)) {
      p(.style(eyebrowStyle)) { "Progress" }
      h2(.style(sectionTitleStyle)) { "\(store.completionPercent)% complete" }

      div(.style(metricsGridStyle)) {
        MetricCard(label: "Total", value: "\(store.todos.count)")
        MetricCard(label: "Active", value: "\(store.activeCount)")
        MetricCard(label: "Completed", value: "\(store.completedCount)")
      }
    }
  }
}
