import Foundation

public enum Boundary: String, Codable, CaseIterable, Sendable {
  case ring, zero, clamp, reflect

  public var title: String {
    switch self {
    case .ring: return "Ring"
    case .zero: return "Zero outside"
    case .clamp: return "Clamp at ends"
    case .reflect: return "Reflect at ends"
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    // Version 1.0 stored translated labels instead of stable identifiers.
    let legacy: [String: Self] = [
      "Çember": .ring, "Dışarısı sıfır": .zero, "Uçta sabit": .clamp, "Uçta yansıma": .reflect,
    ]
    guard let decoded = Self(rawValue: value) ?? legacy[value] else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Unknown boundary identifier.")
    }
    self = decoded
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

public enum UpdateOrder: String, Codable, CaseIterable, Sendable {
  case simultaneous, forward, backward

  public var title: String {
    switch self {
    case .simultaneous: return "Simultaneous"
    case .forward: return "In place: 1 → n"
    case .backward: return "In place: n → 1"
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    let legacy: [String: Self] = [
      "Eşzamanlı": .simultaneous, "Sırayla: 1 → n": .forward, "Sırayla: n → 1": .backward,
    ]
    guard let decoded = Self(rawValue: value) ?? legacy[value] else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Unknown update-order identifier.")
    }
    self = decoded
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
public struct Rule: Codable, Equatable, Sendable {
  public var count = 3
  public var distance = 1
  public var direction = 1
  public var boundary: Boundary = .ring
  public var order: UpdateOrder = .simultaneous
  public var own = 1
  public var neighbor = -1
  public var constant = 0
  public var absolute = true
  public var modular = false
  public var modulus = 2
  public var maxSteps = 2000
  public init() {}
  public func validate() throws {
    guard (2...128).contains(count), (0...127).contains(distance), [-1, 1].contains(direction),
      (-1000...1000).contains(own), (-1000...1000).contains(neighbor),
      (-1_000_000...1_000_000).contains(constant),
      (2...1_000_000_000).contains(modulus), (1...10000).contains(maxSteps)
    else { throw ExperimentError.invalidRule }
  }
  public func neighborIndex(_ index: Int) -> Int? {
    let j = index + direction * distance
    switch boundary {
    case .ring: return ((j % count) + count) % count
    case .zero: return (0..<count).contains(j) ? j : nil
    case .clamp: return min(count - 1, max(0, j))
    case .reflect:
      let period = 2 * (count - 1)
      let r = ((j % period) + period) % period
      return r < count ? r : period - r
    }
  }
  public var formula: String {
    var s = "\(own)·xᵢ + (\(neighbor))·xⱼ + (\(constant))"
    if absolute { s = "| " + s + " |" }
    if modular { s = "(" + s + ") mod \(modulus)" }
    return "xᵢ′ = " + s
  }
  public var shortName: String {
    "n=\(count) · \(absolute ? "absolute" : "signed")\(modular ? " mod \(modulus)" : "")"
  }
  public func next(_ input: [ExactInteger]) -> [ExactInteger] {
    precondition(input.count == count)
    var output = input
    let indices = order == .backward ? Array((0..<count).reversed()) : Array(0..<count)
    for i in indices {
      let source = order == .simultaneous ? input : output
      let other = neighborIndex(i).map { source[$0] } ?? .zero
      var v = source[i] * own + other * neighbor + ExactInteger(constant)
      if absolute { v = v.magnitude }
      if modular { v = v.modulo(modulus) }
      output[i] = v
    }
    return output
  }
}
public enum ExperimentError: LocalizedError {
  case invalidRule
  case invalidInput(String)
  case limit(String)
  case invalidFile
  public var errorDescription: String? {
    switch self {
    case .invalidRule: return "Rule parameters are outside the supported ranges."
    case .invalidInput(let message): return message
    case .limit(let message): return message
    case .invalidFile: return "The experiment file is invalid or incompatible with this version."
    }
  }
}
public struct Cycle: Equatable, Sendable {
  public var start: Int
  public var period: Int
  public init(start: Int, period: Int) {
    self.start = start
    self.period = period
  }
}
public struct Recipe: Codable, Sendable {
  public var name: String
  public var rule: Rule
  public var initial: [String]
  public var steps: Int
  public var selectedStep: Int
  public init(name: String, rule: Rule, initial: [String], steps: Int, selectedStep: Int) {
    self.name = name
    self.rule = rule
    self.initial = initial
    self.steps = steps
    self.selectedStep = selectedStep
  }
}
public struct ExperimentFile: Codable, Sendable {
  public var version = 1
  public var experiment: Recipe
  public var comparisons: [Recipe]
  public init(experiment: Recipe, comparisons: [Recipe] = []) {
    self.experiment = experiment
    self.comparisons = comparisons
  }
}
public struct Experiment: Sendable {
  public let rule: Rule
  public private(set) var states: [[ExactInteger]]
  public private(set) var peaks: [Double]
  public private(set) var cycle: Cycle?
  private var seen: [String: Int]
  private var storedDigits: Int
  public var lastStep: Int { states.count - 1 }
  public init(rule: Rule, initial: [String]) throws {
    try rule.validate()
    guard initial.count == rule.count else {
      throw ExperimentError.invalidInput(
        "Enter exactly \(rule.count) initial values for \(rule.count) nodes.")
    }
    let parsed = try initial.enumerated().map { i, text -> ExactInteger in
      guard text.count <= 1001, let v = ExactInteger(text), v.decimalDigits <= 1000 else {
        throw ExperimentError.invalidInput(
          "Node \(i+1) must contain a valid integer with at most 1,000 digits.")
      }
      return v
    }
    self.rule = rule
    states = [parsed]
    peaks = [parsed.map(\.logMagnitude).max() ?? 0]
    cycle = nil
    seen = [Self.key(parsed): 0]
    storedDigits = parsed.reduce(0) { $0 + $1.decimalDigits }
  }
  private static func key(_ values: [ExactInteger]) -> String {
    values.map(\.description).joined(separator: ",")
  }
  public mutating func advance() throws {
    guard lastStep < rule.maxSteps else {
      throw ExperimentError.limit(
        "Reached the \(rule.maxSteps)-step history limit. Increase it in settings and apply a new experiment."
      )
    }
    guard (states.count + 1) * rule.count <= 250_000 else {
      throw ExperimentError.limit(
        "Reached the stored-value limit for this experiment. Existing results are preserved.")
    }
    let values = rule.next(states.last!)
    let digits = values.reduce(0) { $0 + $1.decimalDigits }
    guard values.allSatisfy({ $0.decimalDigits <= 2000 }), storedDigits + digits <= 2_000_000 else {
      throw ExperimentError.limit(
        "Reached the integer storage limit; calculation stopped. Results were not rounded.")
    }
    let index = states.count
    let key = Self.key(values)
    if cycle == nil, let first = seen[key] { cycle = Cycle(start: first, period: index - first) }
    if seen[key] == nil { seen[key] = index }
    storedDigits += digits
    states.append(values)
    peaks.append(values.map(\.logMagnitude).max() ?? 0)
  }
  public func recipe(name: String, selectedStep: Int) -> Recipe {
    Recipe(
      name: name, rule: rule, initial: states[0].map(\.description), steps: lastStep,
      selectedStep: selectedStep)
  }
  public static func restore(_ recipe: Recipe) throws -> Self {
    guard recipe.steps >= 0, recipe.steps <= recipe.rule.maxSteps else {
      throw ExperimentError.invalidFile
    }
    var result = try Self(rule: recipe.rule, initial: recipe.initial)
    for _ in 0..<recipe.steps {
      if Task.isCancelled { throw CancellationError() }
      try result.advance()
    }
    return result
  }
  public var csv: String {
    var lines = [(["step"] + (1...rule.count).map { "x\($0)" }).joined(separator: ",")]
    for (i, state) in states.enumerated() {
      lines.append(([String(i)] + state.map(\.description)).joined(separator: ","))
    }
    return lines.joined(separator: "\n") + "\n"
  }
}

public struct BinaryScanResult: Sendable {
  public var count: Int
  public var states: Int
  public var cycleCounts: [Int: Int]
  public var basinCounts: [Int: Int]
  public var witnesses: [Int: [String]]
  public var summary: String {
    let rows = cycleCounts.keys.sorted().map { p in
      "Period \(p): \(cycleCounts[p]!) cycles; \(basinCounts[p] ?? 0) initial states reach this period."
    }
    return "n = \(count) · \(states) initial states scanned.\n" + rows.joined(separator: "\n")
  }
}
/// Exhaustive finite calculation, never evidence for all n. Restricted to the classic binary ring.
public func scanBinary(count n: Int) throws -> BinaryScanResult {
  guard (2...18).contains(n) else {
    throw ExperimentError.invalidInput("Exhaustive scans require n between 2 and 18.")
  }
  let size = 1 << n
  var assigned = [Int](repeating: 0, count: size)
  var cycles: [Int: Int] = [:]
  var basins: [Int: Int] = [:]
  var witnesses: [Int: [String]] = [:]
  func next(_ x: Int) -> Int { x ^ ((x >> 1) | ((x & 1) << (n - 1))) }
  for start in 0..<size {
    if start % 1024 == 0 && Task.isCancelled { throw CancellationError() }
    if assigned[start] != 0 { continue }
    var path: [Int] = []
    var positions: [Int: Int] = [:]
    var x = start
    while assigned[x] == 0 && positions[x] == nil {
      positions[x] = path.count
      path.append(x)
      x = next(x)
    }
    let period: Int
    if let first = positions[x] {
      period = path.count - first
      cycles[period, default: 0] += 1
      if witnesses[period] == nil { witnesses[period] = (0..<n).map { String((x >> $0) & 1) } }
    } else {
      period = assigned[x]
    }
    for value in path {
      assigned[value] = period
      basins[period, default: 0] += 1
    }
  }
  return BinaryScanResult(
    count: n, states: size, cycleCounts: cycles, basinCounts: basins, witnesses: witnesses)
}
