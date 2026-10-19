import Foundation

/// Signed, arbitrary precision decimal integer. No floating point enters the recurrence.
public struct ExactInteger: Equatable, Hashable, Sendable, CustomStringConvertible {
  private static let base: UInt64 = 1_000_000_000
  private var sign: Int
  private var limbs: [UInt32]
  public static let zero = ExactInteger(0)

  public init(_ value: Int) {
    sign = value == 0 ? 0 : (value < 0 ? -1 : 1)
    var magnitude = value.magnitude
    limbs = []
    while magnitude > 0 {
      limbs.append(UInt32(magnitude % UInt(Self.base)))
      magnitude /= UInt(Self.base)
    }
  }
  public init?(_ text: String) {
    var string = text.trimmingCharacters(in: .whitespacesAndNewlines)
    var s = 1
    if string.first == "-" {
      s = -1
      string.removeFirst()
    } else if string.first == "+" {
      string.removeFirst()
    }
    guard !string.isEmpty, string.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }) else { return nil }
    limbs = []
    sign = s
    while !string.isEmpty {
      let cut = string.index(string.endIndex, offsetBy: -min(9, string.count))
      guard let limb = UInt32(string[cut...]) else { return nil }
      limbs.append(limb)
      string.removeSubrange(cut...)
    }
    normalize()
  }
  private init(sign: Int, limbs: [UInt32]) {
    self.sign = sign
    self.limbs = limbs
    normalize()
  }
  private mutating func normalize() {
    while limbs.last == 0 { limbs.removeLast() }
    if limbs.isEmpty { sign = 0 }
  }
  public var description: String {
    guard let high = limbs.last else { return "0" }
    return (sign < 0 ? "-" : "") + String(high)
      + limbs.dropLast().reversed().map { String(format: "%09u", $0) }.joined()
  }
  public var signum: Int { sign }
  public var magnitude: Self { Self(sign: abs(sign), limbs: limbs) }
  public var decimalDigits: Int {
    guard let last = limbs.last else { return 1 }
    return (limbs.count - 1) * 9 + String(last).count
  }
  public var logMagnitude: Double {
    guard let last = limbs.last else { return 0 }
    let head =
      Double(last) + (limbs.count > 1 ? Double(limbs[limbs.count - 2]) / Double(Self.base) : 0)
    let logValue = log10(head) + Double(limbs.count - 1) * 9
    return logValue > 12 ? logValue : log10(1 + pow(10, logValue))
  }
  public var signedLog: Double { Double(sign) * logMagnitude }
  public var approximate: Double {
    guard sign != 0 else { return 0 }
    guard decimalDigits < 305 else { return Double(sign) * Double.greatestFiniteMagnitude }
    return Double(description) ?? Double(sign) * Double.greatestFiniteMagnitude
  }
  public func abbreviated(_ limit: Int = 12) -> String {
    let text = description
    guard text.count > limit else { return text }
    return String(text.prefix(max(3, limit - 5))) + "…(" + String(decimalDigits) + ")"
  }
  private static func compare(_ a: [UInt32], _ b: [UInt32]) -> Int {
    if a.count != b.count { return a.count < b.count ? -1 : 1 }
    for (x, y) in zip(a.reversed(), b.reversed()) { if x != y { return x < y ? -1 : 1 } }
    return 0
  }
  public func magnitudeExceeds(_ other: Self) -> Bool { Self.compare(limbs, other.limbs) > 0 }
  private static func add(_ a: [UInt32], _ b: [UInt32]) -> [UInt32] {
    var out: [UInt32] = []
    var carry: UInt64 = 0
    for i in 0..<max(a.count, b.count) {
      let v = UInt64(i < a.count ? a[i] : 0) + UInt64(i < b.count ? b[i] : 0) + carry
      out.append(UInt32(v % base))
      carry = v / base
    }
    if carry > 0 { out.append(UInt32(carry)) }
    return out
  }
  private static func subtract(_ a: [UInt32], _ b: [UInt32]) -> [UInt32] {
    var out: [UInt32] = []
    var borrow: Int64 = 0
    for i in 0..<a.count {
      var v = Int64(a[i]) - Int64(i < b.count ? b[i] : 0) - borrow
      borrow = v < 0 ? 1 : 0
      if v < 0 { v += Int64(base) }
      out.append(UInt32(v))
    }
    return out
  }
  public static prefix func - (value: Self) -> Self { Self(sign: -value.sign, limbs: value.limbs) }
  public static func + (a: Self, b: Self) -> Self {
    if a.sign == 0 { return b }
    if b.sign == 0 { return a }
    if a.sign == b.sign { return Self(sign: a.sign, limbs: add(a.limbs, b.limbs)) }
    let c = compare(a.limbs, b.limbs)
    return c == 0
      ? .zero
      : c > 0
        ? Self(sign: a.sign, limbs: subtract(a.limbs, b.limbs))
        : Self(sign: b.sign, limbs: subtract(b.limbs, a.limbs))
  }
  public static func - (a: Self, b: Self) -> Self { a + (-b) }
  public static func * (a: Self, factor: Int) -> Self {
    guard factor != 0, a.sign != 0 else { return .zero }
    precondition(factor.magnitude <= 1_000_000_000)
    var out: [UInt32] = []
    var carry: UInt64 = 0
    for limb in a.limbs {
      let v = UInt64(limb) * UInt64(factor.magnitude) + carry
      out.append(UInt32(v % base))
      carry = v / base
    }
    while carry > 0 {
      out.append(UInt32(carry % base))
      carry /= base
    }
    return Self(sign: a.sign * (factor < 0 ? -1 : 1), limbs: out)
  }
  public func modulo(_ modulus: Int) -> Self {
    precondition(modulus > 0 && modulus <= 1_000_000_000)
    var remainder: UInt64 = 0
    for limb in limbs.reversed() {
      remainder = (remainder * Self.base + UInt64(limb)) % UInt64(modulus)
    }
    let r = Int(remainder)
    return Self(sign < 0 && r != 0 ? modulus - r : r)
  }
}
