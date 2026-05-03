let pageStyle = [
  "box-sizing": "border-box",
  "min-height": "100vh",
  "padding": "32px",
  "background": "#eef2f6",
  "color": "#16202a",
  "font-family": "-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
]

let headerStyle = [
  "display": "flex",
  "align-items": "center",
  "justify-content": "space-between",
  "gap": "24px",
  "max-width": "1040px",
  "margin": "0 auto 20px",
]

let eyebrowStyle = [
  "margin": "0 0 6px",
  "font-size": "12px",
  "font-weight": "700",
  "letter-spacing": "0",
  "text-transform": "uppercase",
  "color": "#576272",
]

let titleStyle = [
  "margin": "0",
  "font-size": "34px",
  "font-weight": "760",
]

let summaryPillStyle = [
  "padding": "10px 14px",
  "border": "1px solid #cad3df",
  "border-radius": "999px",
  "background": "#ffffff",
  "font-size": "14px",
  "font-weight": "650",
]

let navStyle = [
  "display": "flex",
  "gap": "10px",
  "max-width": "1040px",
  "margin": "0 auto 20px",
]

let mainStyle = [
  "max-width": "1040px",
  "margin": "0 auto",
]

let panelStyle = [
  "box-sizing": "border-box",
  "padding": "24px",
  "border": "1px solid #d4dce7",
  "border-radius": "8px",
  "background": "#ffffff",
  "box-shadow": "0 12px 28px rgba(25, 38, 55, 0.08)",
]

let sectionHeaderStyle = [
  "display": "flex",
  "align-items": "center",
  "justify-content": "space-between",
  "gap": "16px",
  "margin": "0 0 18px",
]

let sectionTitleStyle = [
  "margin": "0",
  "font-size": "24px",
  "font-weight": "720",
]

let composerStyle = [
  "display": "grid",
  "grid-template-columns": "minmax(0, 1fr) 180px auto",
  "gap": "10px",
  "margin": "0 0 18px",
]

let inputStyle = [
  "box-sizing": "border-box",
  "width": "100%",
  "padding": "11px 12px",
  "border": "1px solid #c7d0dc",
  "border-radius": "6px",
  "font": "inherit",
]

let projectInputStyle = inputStyle

let primaryButtonStyle = [
  "padding": "10px 14px",
  "border": "1px solid #1d5fd0",
  "border-radius": "6px",
  "background": "#2167e0",
  "color": "#ffffff",
  "font": "inherit",
  "font-weight": "680",
]

let secondaryButtonStyle = [
  "padding": "10px 14px",
  "border": "1px solid #c7d0dc",
  "border-radius": "6px",
  "background": "#f8fafc",
  "color": "#253143",
  "font": "inherit",
  "font-weight": "650",
]

let dangerButtonStyle = [
  "padding": "8px 10px",
  "border": "1px solid #e7c4c4",
  "border-radius": "6px",
  "background": "#fff4f4",
  "color": "#9d2424",
  "font": "inherit",
  "font-weight": "650",
]

let listStyle = [
  "display": "grid",
  "gap": "10px",
]

func rowStyle(isCompleted: Bool) -> [String: String] {
  [
    "display": "grid",
    "grid-template-columns": "24px minmax(0, 1fr) auto",
    "align-items": "center",
    "gap": "12px",
    "padding": "12px",
    "border": "1px solid #dce3ec",
    "border-radius": "8px",
    "background": isCompleted ? "#f7f8fa" : "#ffffff",
    "opacity": isCompleted ? "0.72" : "1",
  ]
}

let rowContentStyle = [
  "display": "flex",
  "align-items": "center",
  "gap": "10px",
  "min-width": "0",
]

let projectBadgeStyle = [
  "padding": "4px 8px",
  "border-radius": "999px",
  "background": "#e7f0ff",
  "color": "#2358a6",
  "font-size": "12px",
  "font-weight": "700",
]

let emptyStateStyle = [
  "padding": "32px",
  "border": "1px dashed #c7d0dc",
  "border-radius": "8px",
  "text-align": "center",
  "background": "#f8fafc",
]

let emptyTitleStyle = [
  "margin": "0 0 8px",
  "font-size": "18px",
]

let mutedTextStyle = [
  "margin": "0",
  "color": "#657184",
  "line-height": "1.6",
]

let detailsStyle = [
  "display": "grid",
  "grid-template-columns": "120px 1fr",
  "gap": "10px 16px",
  "margin": "20px 0",
]

let metricsGridStyle = [
  "display": "grid",
  "grid-template-columns": "repeat(3, minmax(0, 1fr))",
  "gap": "12px",
  "margin": "20px 0 0",
]

let metricCardStyle = [
  "padding": "18px",
  "border": "1px solid #dce3ec",
  "border-radius": "8px",
  "background": "#f8fafc",
]

let metricValueStyle = [
  "margin": "0 0 4px",
  "font-size": "28px",
  "font-weight": "760",
]
