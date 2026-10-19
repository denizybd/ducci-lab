import AppKit
import DucciCore
import SwiftUI

@main enum DucciApplication {
  @MainActor static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    withExtendedLifetime(delegate) { app.run() }
  }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
  var window: NSWindow!
  var store: LabStore!
  func applicationDidFinishLaunching(_ notification: Notification) {
    let smoke = CommandLine.arguments.contains("--ui-smoke")
    store = LabStore(restore: !smoke)
    window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1260, height: 850),
      styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false
    )
    window.title = "Ducci Lab"
    window.minSize = NSSize(width: 1040, height: 730)
    window.contentView = NSHostingView(rootView: ContentView(store: store))
    window.center()
    if !smoke { window.setFrameAutosaveName("DucciLabMainWindow") }
    window.makeKeyAndOrderFront(nil)
    buildMenu()
    NSApp.activate(ignoringOtherApps: true)
    if smoke { Task { await runUISmoke() } }
  }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
  func applicationWillTerminate(_ notification: Notification) { store?.shutdown() }
  private func buildMenu() {
    let menu = NSMenu()
    let appItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(
      withTitle: "About Ducci Lab",
      action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
    appMenu.addItem(.separator())
    appMenu.addItem(
      withTitle: "Quit Ducci Lab", action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q")
    appItem.submenu = appMenu
    menu.addItem(appItem)
    let fileItem = NSMenuItem()
    let file = NSMenu(title: "File")
    for (title, action, key) in [
      ("Open Experiment…", #selector(openFile), "o"),
      ("Save Experiment…", #selector(saveFile), "s"), ("Export CSV…", #selector(exportCSV), "e"),
    ] {
      let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
      item.target = self
      file.addItem(item)
    }
    fileItem.submenu = file
    menu.addItem(fileItem)
    let editItem = NSMenuItem()
    let edit = NSMenu(title: "Edit")
    edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
    edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    edit.addItem(
      withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    editItem.submenu = edit
    menu.addItem(editItem)
    let winItem = NSMenuItem()
    let win = NSMenu(title: "Window")
    win.addItem(
      withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
    winItem.submenu = win
    menu.addItem(winItem)
    NSApp.windowsMenu = win
    NSApp.mainMenu = menu
  }
  @objc func openFile() { store.openExperiment() }
  @objc func saveFile() { store.export(csv: false) }
  @objc func exportCSV() { store.export(csv: true) }
  private func waitForCalculation() async {
    for _ in 0..<600 {
      if !store.busy && !store.scanning { return }
      try? await Task.sleep(nanoseconds: 50_000_000)
    }
  }
  private func capture(_ name: String) throws {
    guard let view = window.contentView else { throw ExperimentError.invalidFile }
    view.layoutSubtreeIfNeeded()
    view.displayIfNeeded()
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
      throw ExperimentError.invalidFile
    }
    view.cacheDisplay(in: view.bounds, to: bitmap)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
      throw ExperimentError.invalidFile
    }
    let dir = URL(
      fileURLWithPath: ProcessInfo.processInfo.environment["DUCCI_QA_DIR"] ?? FileManager.default
        .currentDirectoryPath + "/qa")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try data.write(to: dir.appendingPathComponent(name + ".png"))
  }
  private func runUISmoke() async {
    do {
      try await Task.sleep(nanoseconds: 800_000_000)
      store.preset(1)
      store.stopOnRepeat = false
      store.advance(40)
      await waitForCalculation()
      guard store.experiment.lastStep == 40, store.error == nil else {
        throw ExperimentError.invalidInput("Signed progression failed")
      }
      store.pin()
      store.preset(0)
      store.advance(20)
      await waitForCalculation()
      guard store.experiment.cycle?.period == 3 else {
        throw ExperimentError.invalidInput("Cycle detection failed")
      }
      store.selectedStep = 2
      store.viewMode = 0
      try await Task.sleep(nanoseconds: 250_000_000)
      try capture("01-ring")
      store.viewMode = 1
      try await Task.sleep(nanoseconds: 200_000_000)
      try capture("02-time-map")
      store.viewMode = 2
      try await Task.sleep(nanoseconds: 200_000_000)
      try capture("03-plots")
      store.viewMode = 3
      try await Task.sleep(nanoseconds: 200_000_000)
      try capture("04-exact-values")
      store.viewMode = 4
      store.scanCount = 9
      store.startScan()
      await waitForCalculation()
      guard store.scan?.cycleCounts == [1: 1, 3: 1, 63: 4] else {
        throw ExperimentError.invalidInput("Binary scan failed")
      }
      try await Task.sleep(nanoseconds: 200_000_000)
      try capture("05-binary-scan")
      window.setContentSize(NSSize(width: 1040, height: 730))
      store.viewMode = 0
      try await Task.sleep(nanoseconds: 250_000_000)
      try capture("06-compact")
      store.preset(1)
      store.stopOnRepeat = true
      store.references = []
      print(
        "UI smoke: PASS · 5 views, compact layout, signed progression, cycle and exhaustive scan")
      NSApp.terminate(nil)
    } catch {
      fputs("UI smoke: FAIL · \(error)\n", stderr)
      Foundation.exit(1)
    }
  }
}
