import ElementaryUI

@View
struct MetricCard {
  let label: String
  let value: String

  var body: some View {
    div(.style(metricCardStyle)) {
      p(.style(metricValueStyle)) { value }
      p(.style(mutedTextStyle)) { label }
    }
  }
}
