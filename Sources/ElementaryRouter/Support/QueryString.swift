enum QueryString {
  static func parse(_ queryString: String) -> RouteParameters {
    var values = RouteParameters()
    let query = RouteLocation.trimmedQuery(queryString)
    guard !query.isEmpty else { return values }

    var segmentStart = query.startIndex
    var index = query.startIndex

    while true {
      if index == query.endIndex || query[index] == "&" {
        appendPair(String(query[segmentStart..<index]), to: &values)
        if index == query.endIndex { break }
        segmentStart = query.index(after: index)
      }
      index = query.index(after: index)
    }

    return values
  }

  static func stringify(_ values: RouteParameters) -> String {
    var result = ""
    var isFirst = true
    for (name, value) in values.pairs {
      if isFirst {
        isFirst = false
      } else {
        result += "&"
      }
      result += URLCoding.encode(name, spaceAsPlus: true)
      result += "="
      result += URLCoding.encode(value, spaceAsPlus: true)
    }
    return result
  }

  private static func appendPair(_ pair: String, to values: inout RouteParameters) {
    if pair.isEmpty { return }

    var separator = pair.endIndex
    var foundSeparator = false
    var index = pair.startIndex
    while index < pair.endIndex {
      if pair[index] == "=" {
        separator = index
        foundSeparator = true
        break
      }
      index = pair.index(after: index)
    }

    let rawName = String(pair[..<separator])
    let rawValue = foundSeparator ? String(pair[pair.index(after: separator)..<pair.endIndex]) : ""
    let name = URLCoding.decode(rawName, plusIsSpace: true)
    let value = URLCoding.decode(rawValue, plusIsSpace: true)
    values.append(name, value)
  }
}
