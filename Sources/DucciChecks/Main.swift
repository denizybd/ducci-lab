import DucciCore
import Foundation

@main enum Checks {
  static func main() throws {
    var checks = 0
    func require(_ condition: Bool, _ title: String) throws {
      guard condition else { throw ExperimentError.invalidInput("FAIL: " + title) }
      checks += 1
    }
    func strings(_ values: [ExactInteger]) -> [String] { values.map(\.description) }
    for a in stride(from: -100_000, through: 100_000, by: 7331) {
      for b in stride(from: -90_000, through: 90_000, by: 9173) {
        let x = ExactInteger(a)
        let y = ExactInteger(b)
        try require((x + y).description == String(a + b), "signed addition")
        try require((x - y).description == String(a - b), "signed subtraction")
        try require((x * -999).description == String(a * -999), "multiplication")
        try require(x.modulo(17).description == String((a % 17 + 17) % 17), "Euclidean modulo")
      }
    }
    let huge = ExactInteger(
      "9999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999"
    )!
    try require(
      (huge + ExactInteger(1)).description == "1" + String(repeating: "0", count: 100),
      "100-digit carry")
    try require(((huge + ExactInteger(1)) - huge) == ExactInteger(1), "100-digit borrow")
    try require(ExactInteger("-0000") == ExactInteger.zero, "canonical zero")
    try require(
      ExactInteger("12.0") == nil && ExactInteger("−1") == nil, "reject non-decimal values")
    try require(
      abs(ExactInteger("1000000000000000000000000000000")!.signedLog - 30) < 1e-10, "log projection"
    )
    var rule = Rule()
    var classic = try Experiment(rule: Rule(), initial: ["1", "0", "0"])
    try classic.advance()
    try require(strings(classic.states[1]) == ["1", "0", "1"], "absolute step")
    for _ in 0..<3 { try classic.advance() }
    try require(classic.cycle == Cycle(start: 1, period: 3), "exact transient and cycle")
    rule.absolute = false
    var signed = try Experiment(rule: rule, initial: ["1", "0", "0"])
    for _ in 0..<120 { try signed.advance() }
    try require(strings(signed.states[7]) == ["-27", "0", "27"], "signed trajectory")
    for t in 1...110 {
      try require(
        signed.states[t + 6] == signed.states[t].map { $0 * -27 }, "six-step growth identity")
    }
    for state in signed.states.dropFirst() {
      try require(state.reduce(.zero, +) == .zero, "zero-sum invariant")
    }
    try require(
      signed.states.last!.map(\.decimalDigits).max()! > 20 && signed.cycle == nil,
      "large integers never wrap into a false cycle")
    rule.absolute = true
    rule.direction = -1
    try require(
      strings(rule.next([ExactInteger(1), .zero, .zero])) == ["1", "1", "0"],
      "reverse neighbor direction")
    rule.direction = 1
    rule.distance = 0
    try require(
      rule.next([ExactInteger(3), ExactInteger(-8), ExactInteger(9)]) == [.zero, .zero, .zero],
      "self-neighbor")
    rule.distance = 1
    rule.absolute = false
    rule.order = .forward
    try require(
      strings(rule.next([ExactInteger(1), .zero, .zero])) == ["1", "0", "-1"], "forward scan")
    rule.order = .backward
    try require(
      strings(rule.next([ExactInteger(1), .zero, .zero])) == ["0", "1", "-1"],
      "backward in-place scan")
    rule.order = .simultaneous
    rule.direction = -1
    rule.boundary = .zero
    try require(
      strings(rule.next([ExactInteger(1), ExactInteger(2), ExactInteger(3)])) == ["1", "1", "1"],
      "zero boundary")
    rule.boundary = .clamp
    try require(
      strings(rule.next([ExactInteger(1), ExactInteger(2), ExactInteger(3)])) == ["0", "1", "1"],
      "clamped boundary")
    rule.boundary = .reflect
    try require(
      strings(rule.next([ExactInteger(1), ExactInteger(2), ExactInteger(3)])) == ["-1", "1", "1"],
      "reflected boundary")
    rule = Rule()
    rule.absolute = false
    rule.modular = true
    rule.modulus = 7
    try require(
      strings(rule.next([.zero, ExactInteger(1), ExactInteger(3)])) == ["6", "5", "3"],
      "positive modular residues")
    rule.absolute = true
    try require(
      strings(rule.next([.zero, ExactInteger(1), ExactInteger(3)])) == ["1", "2", "3"],
      "abs before modulo")
    let file = ExperimentFile(
      experiment: signed.recipe(name: "Exact roundtrip", selectedStep: 9),
      comparisons: [classic.recipe(name: "Classic", selectedStep: 2)])
    let decoded = try JSONDecoder().decode(ExperimentFile.self, from: JSONEncoder().encode(file))
    let restored = try Experiment.restore(decoded.experiment)
    try require(
      restored.states == signed.states && restored.rule == signed.rule,
      "JSON recipe reproducibility")
    try require(classic.csv.hasPrefix("step,x1,x2,x3\n0,1,0,0\n1,1,0,1\n"), "CSV exact export")
    for (n, expected) in [
      (3, [1: 1, 3: 1]), (5, [1: 1, 15: 1]), (9, [1: 1, 3: 1, 63: 4]),
      (17, [1: 1, 85: 3, 255: 256]),
    ] {
      let scan = try scanBinary(count: n)
      try require(scan.cycleCounts == expected, "complete binary scan n=\(n)")
      try require(scan.basinCounts.values.reduce(0, +) == 1 << n, "scan covers every start")
      for (period, initial) in scan.witnesses {
        var r = Rule()
        r.count = n
        var e = try Experiment(rule: r, initial: initial)
        for _ in 0...period {
          try e.advance()
          if e.cycle != nil { break }
        }
        try require(e.cycle?.period == period, "scan witness matches recurrence")
      }
    }
    var boundedRule = Rule()
    boundedRule.maxSteps = 1
    var bounded = try Experiment(rule: boundedRule, initial: ["1", "0", "0"])
    try bounded.advance()
    do {
      try bounded.advance()
      throw ExperimentError.invalidInput("missing limit")
    } catch ExperimentError.limit { checks += 1 }
    try require(bounded.lastStep == 1, "limit leaves history intact")
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()
    for (old, expected) in [
      ("Çember", Boundary.ring), ("Dışarısı sıfır", .zero), ("Uçta sabit", .clamp),
      ("Uçta yansıma", .reflect),
    ] {
      let value = try decoder.decode(Boundary.self, from: encoder.encode(old))
      try require(value == expected, "legacy boundary decoding")
      let encoded = try decoder.decode(String.self, from: encoder.encode(value))
      try require(encoded == expected.rawValue, "stable boundary encoding")
    }
    for (old, expected) in [
      ("Eşzamanlı", UpdateOrder.simultaneous), ("Sırayla: 1 → n", .forward),
      ("Sırayla: n → 1", .backward),
    ] {
      let value = try decoder.decode(UpdateOrder.self, from: encoder.encode(old))
      try require(value == expected, "legacy update-order decoding")
      let encoded = try decoder.decode(String.self, from: encoder.encode(value))
      try require(encoded == expected.rawValue, "stable update-order encoding")
    }
    let canonical = try encoder.encode(
      ExperimentFile(experiment: classic.recipe(name: "Özel deney adı", selectedStep: 2)))
    var legacy = try JSONSerialization.jsonObject(with: canonical) as! [String: Any]
    var legacyRecipe = legacy["experiment"] as! [String: Any]
    var legacyRule = legacyRecipe["rule"] as! [String: Any]
    legacyRule["boundary"] = "Çember"
    legacyRule["order"] = "Eşzamanlı"
    legacyRecipe["rule"] = legacyRule
    legacy["experiment"] = legacyRecipe
    let legacyFile = try decoder.decode(
      ExperimentFile.self, from: JSONSerialization.data(withJSONObject: legacy))
    let legacyExperiment = try Experiment.restore(legacyFile.experiment)
    try require(legacyExperiment.states == classic.states, "legacy recipe retains exact trajectory")
    try require(
      legacyFile.experiment.name == "Özel deney adı", "user-authored experiment names are preserved"
    )
    for invalid in ["", "missing", "Ring"] {
      do {
        _ = try decoder.decode(Boundary.self, from: encoder.encode(invalid))
        throw ExperimentError.invalidInput("Unknown boundary was accepted")
      } catch is DecodingError { checks += 1 }
    }
    print(
      "DucciChecks: PASS · \(checks) assertions · exact arithmetic, rule variants, growth, recurrence, export, exhaustive scans"
    )
  }
}
