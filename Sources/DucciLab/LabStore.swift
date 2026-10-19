import AppKit
import DucciCore
import SwiftUI
import UniformTypeIdentifiers

struct ReferenceRun: Identifiable {
  let id = UUID()
  let name: String
  let experiment: Experiment
}

@MainActor final class LabStore: ObservableObject {
  @Published var draft = Rule()
  @Published var initialText = "1, 0, 0"
  @Published var name = "First experiment"
  @Published var experiment: Experiment
  @Published var selectedStep = 0
  @Published var selectedNode = 0
  @Published var viewMode = 0
  @Published var playing = false
  @Published var busy = false
  @Published var speed = 4.0
  @Published var stride = 1
  @Published var stopOnRepeat = true
  @Published var signedLog = true
  @Published var showAllNodes = true
  @Published var heatPerRow = false
  @Published var message = "Inspect the initial state or advance one step."
  @Published var error: String?
  @Published var references: [ReferenceRun] = []
  @Published var scanCount = 9
  @Published var scan: BinaryScanResult?
  @Published var scanning = false
  private var timer: Timer?
  private var generation = UUID()
  private var worker: Task<Void, Never>?
  private var scanWorker: Task<Void, Never>?
  private let persistenceURL: URL

  init(restore: Bool = true) {
    experiment = try! Experiment(rule: Rule(), initial: ["1", "0", "0"])
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[
      0
    ].appendingPathComponent("DucciLab", isDirectory: true)
    persistenceURL =
      restore
      ? support.appendingPathComponent("last-experiment.json")
      : URL(
        fileURLWithPath: ProcessInfo.processInfo.environment["DUCCI_QA_DIR"] ?? FileManager.default
          .currentDirectoryPath + "/qa"
      ).appendingPathComponent("last-experiment.json")
    if restore, let data = try? Data(contentsOf: persistenceURL), data.count < 25_000_000 {
      do {
        let file = try JSONDecoder().decode(ExperimentFile.self, from: data)
        guard file.version == 1 else { throw ExperimentError.invalidFile }
        load(file, report: "Restored your last experiment.")
      } catch {
        self.message =
          "New experiment ready. The previous session could not be restored: \(error.localizedDescription)"
      }
    }
    timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.tick() }
    }
  }
  private var lastTick = Date.distantPast
  var state: [ExactInteger] { experiment.states[min(selectedStep, experiment.lastStep)] }
  var valuesText: [String] { Self.parse(initialText) }
  static func parse(_ text: String) -> [String] {
    text.split(whereSeparator: { $0 == "," || $0 == ";" || $0.isWhitespace }).map(String.init)
  }
  var dirty: Bool {
    draft != experiment.rule || valuesText != experiment.states[0].map(\.description)
  }
  var total: ExactInteger { state.reduce(.zero, +) }
  var largest: ExactInteger { state.reduce(.zero) { $1.magnitudeExceeds($0) ? $1.magnitude : $0 } }
  var cycleText: String {
    guard let c = experiment.cycle else { return "No repeated state yet" }
    if experiment.states[c.start].allSatisfy({ $0 == .zero }) { return "Reached zero · period 1" }
    return "Period \(c.period) · starts at \(c.start)"
  }
  func resize(_ n: Int) {
    var values = valuesText
    if values.count < n { values += [String](repeating: "0", count: n - values.count) }
    initialText = values.prefix(n).joined(separator: ", ")
  }
  func apply() {
    do {
      let result = try Experiment(rule: draft, initial: valuesText)
      worker?.cancel()
      generation = UUID()
      playing = false
      busy = false
      experiment = result
      selectedStep = 0
      selectedNode = min(selectedNode, draft.count - 1)
      initialText = result.states[0].map(\.description).joined(separator: ", ")
      message = "New experiment ready. Step 0 is the initial state."
      saveAutomatic()
    } catch { self.error = error.localizedDescription }
  }
  func preset(_ index: Int) {
    var r = Rule()
    name =
      ["Classic Ducci", "Signed difference", "Mod 2", "9-node ring", "17 nodes · period 85"][index]
    switch index {
    case 1: r.absolute = false
    case 2:
      r.absolute = false
      r.modular = true
      r.neighbor = 1
    case 3: r.count = 9
    case 4: r.count = 17
    default: break
    }
    draft = r
    if index == 4 {
      initialText = "0, 1, 1, 0, 1, 1, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1"
    } else {
      initialText = (["1"] + [String](repeating: "0", count: r.count - 1)).joined(separator: ", ")
    }
    apply()
  }
  func randomize(binary: Bool) {
    initialText = (0..<draft.count).map { _ in String(Int.random(in: binary ? 0...1 : -9...9)) }
      .joined(separator: ", ")
  }
  func togglePlayback() {
    guard !busy else { return }
    if playing {
      playing = false
      return
    }
    if dirty {
      error = "Settings have changed. Click “Apply new experiment” first."
      return
    }
    if stopOnRepeat && experiment.cycle != nil && selectedStep == experiment.lastStep {
      message = "Cycle found. Disable “Stop at the first repeated state” to continue."
      return
    }
    playing = true
    lastTick = .distantPast
  }
  private func tick() {
    guard playing, !busy, Date().timeIntervalSince(lastTick) >= 1 / speed else { return }
    lastTick = Date()
    advance(stride)
  }
  func advance(_ count: Int) {
    guard !busy else { return }
    if selectedStep < experiment.lastStep {
      selectedStep = min(experiment.lastStep, selectedStep + count)
      return
    }
    if dirty {
      playing = false
      error = "Settings have changed. Apply the new experiment first."
      return
    }
    busy = true
    let original = experiment
    let token = generation
    let stop = stopOnRepeat
    worker = Task {
      let outcome = await Task.detached(priority: .userInitiated) { () -> (Experiment, String?) in
        var result = original
        for _ in 0..<max(1, min(1000, count)) {
          if Task.isCancelled { return (result, nil) }
          do { try result.advance() } catch { return (result, error.localizedDescription) }
          if stop && result.cycle != nil { break }
        }
        return (result, nil)
      }.value
      guard !Task.isCancelled, token == self.generation else { return }
      self.experiment = outcome.0
      self.selectedStep = outcome.0.lastStep
      self.busy = false
      if let reason = outcome.1 {
        self.playing = false
        self.message = reason
      } else if stop && outcome.0.cycle != nil {
        self.playing = false
        self.message = self.cycleText
      } else {
        self.message = "\(outcome.0.lastStep) steps calculated. Exact integers are preserved."
      }
      self.saveAutomatic()
    }
  }
  func select(_ step: Int) {
    selectedStep = max(0, min(experiment.lastStep, step))
    playing = false
  }
  func pin() {
    guard references.count < 4 else {
      error = "You can pin up to four references. Remove one before adding another."
      return
    }
    references.append(ReferenceRun(name: name, experiment: experiment))
    message = "Experiment pinned for comparison."
    saveAutomatic()
  }
  func branch() {
    let values = state.map(\.description)
    let step = selectedStep
    draft = experiment.rule
    initialText = values.joined(separator: ", ")
    name += " · step \(step) branch"
    apply()
  }
  func copyVector() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(
      state.map(\.description).joined(separator: ", "), forType: .string)
    message = "Copied the exact vector for step \(selectedStep)."
  }
  func document() -> ExperimentFile {
    ExperimentFile(
      experiment: experiment.recipe(name: name, selectedStep: selectedStep),
      comparisons: references.map { $0.experiment.recipe(name: $0.name, selectedStep: 0) })
  }
  func saveAutomatic() {
    do {
      let data = try JSONEncoder().encode(document())
      try FileManager.default.createDirectory(
        at: persistenceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try data.write(to: persistenceURL, options: .atomic)
    } catch { message = "Autosave failed: \(error.localizedDescription)" }
  }
  func export(csv: Bool) {
    playing = false
    let panel = NSSavePanel()
    panel.allowedContentTypes = csv ? [.commaSeparatedText] : [.json]
    panel.nameFieldStringValue = csv ? "Ducci-results.csv" : "Ducci-experiment.json"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      if csv {
        try experiment.csv.write(to: url, atomically: true, encoding: .utf8)
      } else {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(document()).write(to: url, options: .atomic)
      }
      message = "Saved: \(url.lastPathComponent)"
    } catch { self.error = error.localizedDescription }
  }
  func openExperiment() {
    playing = false
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
      guard (attributes[.size] as? NSNumber)?.intValue ?? 0 < 25_000_000 else {
        throw ExperimentError.invalidFile
      }
      let file = try JSONDecoder().decode(ExperimentFile.self, from: Data(contentsOf: url))
      guard file.version == 1, file.comparisons.count <= 4 else {
        throw ExperimentError.invalidFile
      }
      load(file, report: "Experiment opened; results were regenerated from its rule.")
    } catch { self.error = error.localizedDescription }
  }
  private func load(_ file: ExperimentFile, report: String) {
    worker?.cancel()
    generation = UUID()
    let token = generation
    busy = true
    playing = false
    worker = Task {
      do {
        let output = try await Task.detached(priority: .userInitiated) {
          () -> (Experiment, [Experiment]) in
          let current = try Experiment.restore(file.experiment)
          let refs = try file.comparisons.map { try Experiment.restore($0) }
          return (current, refs)
        }.value
        guard !Task.isCancelled, self.generation == token else { return }
        self.experiment = output.0
        self.draft = output.0.rule
        self.initialText = file.experiment.initial.joined(separator: ", ")
        self.name = file.experiment.name
        self.selectedStep = min(output.0.lastStep, max(0, file.experiment.selectedStep))
        self.selectedNode = 0
        self.references = zip(file.comparisons, output.1).map {
          ReferenceRun(name: $0.0.name, experiment: $0.1)
        }
        self.busy = false
        self.message = report
        self.saveAutomatic()
      } catch {
        guard self.generation == token else { return }
        self.busy = false
        self.error = error.localizedDescription
      }
    }
  }
  func startScan() {
    guard !scanning else { return }
    scanning = true
    let n = scanCount
    scanWorker = Task {
      do {
        let result = try await Task.detached(priority: .userInitiated) { try scanBinary(count: n) }
          .value
        guard !Task.isCancelled else { return }
        self.scan = result
        self.scanning = false
      } catch {
        self.scanning = false
        self.error = error.localizedDescription
      }
    }
  }
  func loadWitness(period: Int) {
    guard let scan, let values = scan.witnesses[period] else { return }
    var r = Rule()
    r.count = scan.count
    draft = r
    initialText = values.joined(separator: ", ")
    name = "n=\(scan.count) · period \(period)"
    apply()
    viewMode = 0
  }
  func shutdown() {
    playing = false
    worker?.cancel()
    scanWorker?.cancel()
    timer?.invalidate()
    saveAutomatic()
  }
}
