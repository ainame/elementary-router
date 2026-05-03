enum URLCoding {
  static func decode(_ value: String, plusIsSpace: Bool) -> String {
    var bytes: [UInt8] = []
    let input = Array(value.utf8)
    var index = 0

    while index < input.count {
      let byte = input[index]
      if byte == 37, index + 2 < input.count,
        let high = hexValue(input[index + 1]),
        let low = hexValue(input[index + 2])
      {
        bytes.append(high * 16 + low)
        index += 3
      } else if byte == 43 && plusIsSpace {
        bytes.append(32)
        index += 1
      } else {
        bytes.append(byte)
        index += 1
      }
    }

    return String(decoding: bytes, as: UTF8.self)
  }

  static func encode(_ value: String, spaceAsPlus: Bool) -> String {
    var result = ""
    for byte in value.utf8 {
      if isUnreserved(byte) {
        result.append(Character(UnicodeScalar(byte)))
      } else if byte == 32 && spaceAsPlus {
        result.append("+")
      } else {
        result.append("%")
        result.append(hexCharacter(byte >> 4))
        result.append(hexCharacter(byte & 0x0F))
      }
    }
    return result
  }

  private static func isUnreserved(_ byte: UInt8) -> Bool {
    (byte >= 65 && byte <= 90)
      || (byte >= 97 && byte <= 122)
      || (byte >= 48 && byte <= 57)
      || byte == 45
      || byte == 46
      || byte == 95
      || byte == 126
  }

  private static func hexValue(_ byte: UInt8) -> UInt8? {
    if byte >= 48 && byte <= 57 { return byte - 48 }
    if byte >= 65 && byte <= 70 { return byte - 55 }
    if byte >= 97 && byte <= 102 { return byte - 87 }
    return nil
  }

  private static func hexCharacter(_ value: UInt8) -> Character {
    let byte = value < 10 ? value + 48 : value + 55
    return Character(UnicodeScalar(byte))
  }
}
