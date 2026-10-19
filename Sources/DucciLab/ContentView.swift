import AppKit
import DucciCore
import SwiftUI

private let teal = Color(nsColor: .systemTeal)
private let negative = Color(nsColor: .systemOrange)
private let palette: [Color] = [.teal, .orange, .purple, .blue, .pink]

struct ContentView: View {
  @ObservedObject var store: LabStore
  var body: some View {
    HSplitView {
      sidebar.frame(minWidth: 300, idealWidth: 320, maxWidth: 370)
      workspace.frame(minWidth: 660, maxWidth: .infinity, maxHeight: .infinity)
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .alert(
      "Experiment Lab",
      isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
    ) {
      Button("OK") { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
  }
  private var sidebar: some View {
    VStack(spacing: 0) {
      HStack {
        Image(systemName: "circle.hexagongrid").font(.title2).foregroundStyle(teal)
        VStack(alignment: .leading, spacing: 2) {
          Text("Ducci Lab").font(.title2.weight(.semibold))
          Text("Explore your own rules").font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Menu {
          Button("Classic absolute difference") { store.preset(0) }
          Button("Signed difference") { store.preset(1) }
          Button("Mod 2 · neighbor sum") { store.preset(2) }
          Button("9-node ring") { store.preset(3) }
          Button("17 nodes · period 85") { store.preset(4) }
        } label: {
          Image(systemName: "sparkles")
        }.menuStyle(.borderlessButton).frame(width: 28).help("Presets")
      }.padding(18)
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          VStack(alignment: .leading, spacing: 10) {
            section("INITIAL STATE")
            TextField("Experiment name", text: $store.name)
            Stepper("Nodes: \(store.draft.count)", value: $store.draft.count, in: 2...128)
              .onChange(of: store.draft.count) { _, n in store.resize(n) }
            TextEditor(text: $store.initialText).font(.system(.body, design: .monospaced)).frame(
              height: 76
            ).scrollContentBackground(.hidden).padding(5).background(
              Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
            HStack {
              Text("\(store.valuesText.count) / \(store.draft.count) integers").font(.caption)
                .foregroundStyle(
                  store.valuesText.count == store.draft.count ? Color.secondary : negative)
              Spacer()
              Menu("Generate") {
                Button("Random 0–1") { store.randomize(binary: true) }
                Button("Random −9…9") { store.randomize(binary: false) }
                Button("One 1, all other values 0") {
                  store.initialText =
                    (["1"] + [String](repeating: "0", count: store.draft.count - 1)).joined(
                      separator: ", ")
                }
              }
            }
            Text("Separate values with commas, spaces, or new lines.").font(.caption)
              .foregroundStyle(.secondary)
          }
          VStack(alignment: .leading, spacing: 10) {
            section("NEIGHBORHOOD")
            Picker("Topology", selection: $store.draft.boundary) {
              ForEach(Boundary.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Neighbor direction", selection: $store.draft.direction) {
              Text(store.draft.boundary == .ring ? "Clockwise →" : "Forward (+k) →").tag(1)
              Text(store.draft.boundary == .ring ? "← Counterclockwise" : "← Backward (−k)").tag(-1)
            }.pickerStyle(.segmented)
            Stepper(
              "Neighbor offset: \(store.draft.distance)", value: $store.draft.distance, in: 0...127)
            Picker("Update order", selection: $store.draft.order) {
              ForEach(UpdateOrder.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Text(
              store.draft.order == .simultaneous
                ? "All new values use the previous state."
                : "Each node updates immediately; later nodes may use its new value."
            ).font(.caption).foregroundStyle(.secondary)
          }
          VStack(alignment: .leading, spacing: 10) {
            section("RULE")
            HStack {
              coefficient("Self · a", value: $store.draft.own)
              coefficient("Neighbor · b", value: $store.draft.neighbor)
              coefficient("Constant · c", value: $store.draft.constant)
            }
            Toggle("Take absolute value", isOn: $store.draft.absolute)
            Toggle("Use modular arithmetic", isOn: $store.draft.modular)
            if store.draft.modular {
              HStack {
                Text("Modulus")
                TextField("m", value: $store.draft.modulus, format: .number.grouping(.never))
                  .textFieldStyle(.roundedBorder)
              }
            }
            Text(store.draft.formula).font(.system(.callout, design: .monospaced)).textSelection(
              .enabled
            ).fixedSize(horizontal: false, vertical: true)
            Text(
              "Order: a·self + b·neighbor + c → absolute value → modulo. a,b: −1000…1000; c: −10⁶…10⁶."
            ).font(.caption).foregroundStyle(.secondary)
          }
          VStack(alignment: .leading, spacing: 10) {
            section("TIME")
            HStack {
              Text("History step limit")
              Spacer()
              TextField("Limit", value: $store.draft.maxSteps, format: .number.grouping(.never))
                .frame(width: 76)
            }
            Text(
              "1–10,000 steps. Very large integers stop the calculation without rounding the results."
            ).font(.caption).foregroundStyle(.secondary)
            Toggle("Stop at the first repeated state", isOn: $store.stopOnRepeat)
          }
        }.padding(18)
      }
      Divider()
      VStack(spacing: 8) {
        if store.dirty {
          Label("Unapplied settings", systemImage: "circle.fill").font(.caption).foregroundStyle(
            negative)
        }
        Button("Apply new experiment", action: store.apply).buttonStyle(.borderedProminent)
          .controlSize(.large).frame(maxWidth: .infinity)
        HStack {
          Button("Open…", action: store.openExperiment)
          Button("Save…") { store.export(csv: false) }
          Button("CSV…") { store.export(csv: true) }
        }.font(.caption)
      }.padding(14)
    }.textFieldStyle(.roundedBorder)
  }
  private func section(_ title: String) -> some View {
    Text(title).font(.caption.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
  }
  private func coefficient(_ title: String, value: Binding<Int>) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      TextField(title, value: value, format: .number.grouping(.never))
    }
  }
  private var workspace: some View {
    VStack(spacing: 0) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 5) {
          Text(store.name.isEmpty ? "Untitled experiment" : store.name).font(
            .title2.weight(.medium))
          Text(store.experiment.rule.formula).font(.system(.callout, design: .monospaced))
            .foregroundStyle(.secondary).textSelection(.enabled)
        }
        Spacer()
        Button {
          store.pin()
        } label: {
          Label("Pin for comparison", systemImage: "pin")
        }.disabled(store.busy)
      }.padding(20)
      HStack(spacing: 28) {
        metric(
          "Step", String(store.selectedStep), detail: "history: 0…\(store.experiment.lastStep)")
        metric("Sum", store.total.abbreviated(), detail: "signed sum")
        metric(
          "Largest |x|", store.largest.abbreviated(),
          detail: store.largest.decimalDigits == 1
            ? "1 digit" : "\(store.largest.decimalDigits) digits")
        VStack(alignment: .leading, spacing: 5) {
          Text("Cycle").font(.caption).foregroundStyle(.secondary)
          Text(store.cycleText).font(.callout).foregroundStyle(
            store.experiment.cycle == nil ? Color.secondary : teal)
          Text("Exact values at the same nodes").font(.caption2).foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
      }.padding(.horizontal, 20).padding(.bottom, 18)
      Picker("View", selection: $store.viewMode) {
        Text("Ring / topology").tag(0)
        Text("Time map").tag(1)
        Text("Plots").tag(2)
        Text("Exact values").tag(3)
        Text("Binary scan").tag(4)
      }.pickerStyle(.segmented).padding(.horizontal, 20).padding(.bottom, 12)
      Divider()
      Group {
        switch store.viewMode {
        case 0: RingView(store: store)
        case 1: HeatmapView(store: store)
        case 2: PlotView(store: store)
        case 3: ExactTable(store: store)
        default: BinaryScanView(store: store)
        }
      }.frame(maxWidth: .infinity, maxHeight: .infinity)
      Divider()
      transport.padding(16)
      HStack(spacing: 8) {
        if store.busy { ProgressView().controlSize(.small) }
        Text(store.message).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        Spacer()
        Text("Exact integer arithmetic").font(.caption).foregroundStyle(teal)
      }.padding(.horizontal, 18).padding(.bottom, 12)
    }
  }
  private func metric(_ title: String, _ value: String, detail: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      Text(value).font(.system(.title3, design: .monospaced)).lineLimit(1).help(value)
      Text(detail).font(.caption2).foregroundStyle(.secondary)
    }
  }
  private var transport: some View {
    VStack(spacing: 10) {
      HStack(spacing: 10) {
        Button {
          store.select(0)
        } label: {
          Image(systemName: "backward.end")
        }.help("Go to initial state")
        Button {
          store.select(store.selectedStep - 1)
        } label: {
          Image(systemName: "chevron.left")
        }.disabled(store.selectedStep == 0).help("Previous recorded state")
        Button {
          store.togglePlayback()
        } label: {
          Label(
            store.playing ? "Pause" : "Play",
            systemImage: store.playing ? "pause.fill" : "play.fill")
        }.buttonStyle(.borderedProminent).disabled(store.busy).keyboardShortcut(
          "r", modifiers: .command)
        Button {
          store.advance(store.stride)
        } label: {
          Label("Advance", systemImage: "chevron.right")
        }.disabled(store.busy).keyboardShortcut(.rightArrow, modifiers: .command)
        Button("+100 steps") { store.advance(100) }.disabled(store.busy)
        Spacer()
        Stepper("Steps per advance: \(store.stride)", value: $store.stride, in: 1...100).fixedSize()
        HStack(spacing: 5) {
          Slider(value: $store.speed, in: 1...20).frame(width: 60).help("Advances per second")
          Text("\(Int(store.speed))/s").font(.caption.monospacedDigit()).frame(width: 35)
        }
      }.controlSize(.regular)
      HStack {
        Text("0").font(.caption.monospacedDigit())
        Slider(
          value: Binding(
            get: { Double(store.selectedStep) }, set: { store.select(Int($0.rounded())) }),
          in: 0...Double(max(1, store.experiment.lastStep))
        ).disabled(store.experiment.lastStep == 0)
        Text("\(store.experiment.lastStep)").font(.caption.monospacedDigit())
        TextField(
          "Step", value: Binding(get: { store.selectedStep }, set: { store.select($0) }),
          format: .number.grouping(.never)
        ).textFieldStyle(.roundedBorder).frame(width: 65)
      }
    }
  }
}

struct RingView: View {
  @ObservedObject var store: LabStore
  private func locations(_ size: CGSize) -> [CGPoint] {
    let n = store.state.count
    if store.experiment.rule.boundary != .ring {
      return (0..<n).map {
        CGPoint(x: 40 + CGFloat($0) * max(1, size.width - 80) / CGFloat(n - 1), y: size.height / 2)
      }
    }
    let r = max(30, min(size.width - 110, size.height - 85) / 2)
    let cx = size.width / 2
    let cy = size.height / 2
    return (0..<n).map {
      let a = Double($0) * 2 * .pi / Double(n) - .pi / 2
      return CGPoint(x: cx + r * cos(a), y: cy + r * sin(a))
    }
  }
  var body: some View {
    VStack(spacing: 8) {
      HStack {
        Label("Positive", systemImage: "circle.fill").foregroundStyle(teal)
        Label("Negative", systemImage: "circle.fill").foregroundStyle(negative)
        Label("Zero", systemImage: "circle").foregroundStyle(.secondary)
        Spacer()
        Text("n = \(store.state.count) · \(store.experiment.rule.boundary.title)").foregroundStyle(
          .secondary)
      }.font(.caption)
      GeometryReader { geo in
        Canvas { context, size in
          let points = locations(size)
          let values = store.state
          let n = values.count
          let radius: CGFloat = n <= 12 ? 27 : n <= 24 ? 20 : n <= 48 ? 11 : 5
          for (i, p) in points.enumerated() {
            if let j = store.experiment.rule.neighborIndex(i), j != i {
              let q = points[j]
              let dx = q.x - p.x
              let dy = q.y - p.y
              let d = max(1, hypot(dx, dy))
              let ux = dx / d
              let uy = dy / d
              let start = CGPoint(x: p.x + ux * (radius + 2), y: p.y + uy * (radius + 2))
              let end = CGPoint(x: q.x - ux * (radius + 5), y: q.y - uy * (radius + 5))
              var line = Path()
              line.move(to: start)
              line.addLine(to: end)
              context.stroke(line, with: .color(Color.primary.opacity(0.13)), lineWidth: 1)
              var arrow = Path()
              arrow.move(to: end)
              arrow.addLine(to: CGPoint(x: end.x - ux * 7 - uy * 3, y: end.y - uy * 7 + ux * 3))
              arrow.addLine(to: CGPoint(x: end.x - ux * 7 + uy * 3, y: end.y - uy * 7 - ux * 3))
              arrow.closeSubpath()
              context.fill(arrow, with: .color(.secondary.opacity(0.6)))
            }
          }
          for (i, p) in points.enumerated() {
            let value = values[i]
            let color = value.signum > 0 ? teal : value.signum < 0 ? negative : .secondary
            let circle = Path(
              ellipseIn: CGRect(
                x: p.x - radius, y: p.y - radius, width: 2 * radius, height: 2 * radius))
            context.fill(circle, with: .color(color.opacity(value.signum == 0 ? 0.08 : 0.2)))
            context.stroke(
              circle, with: .color(i == store.selectedNode ? Color.primary : color.opacity(0.55)),
              lineWidth: i == store.selectedNode ? 2.5 : 1)
            if n <= 24 {
              let full = value.description
              let limit = n <= 12 ? 7 : 5
              let short = full.count > limit ? String(full.prefix(limit - 2)) + "…" : full
              context.draw(
                Text(short).font(.system(size: n <= 12 ? 13 : 11, design: .monospaced)), at: p)
              context.draw(
                Text("\(i+1)").font(.system(size: 11)).foregroundStyle(.secondary),
                at: CGPoint(x: p.x, y: p.y + radius + 13))
            }
          }
          if store.experiment.rule.boundary == .ring {
            context.draw(
              Text("Step \(store.selectedStep)").font(.title3).foregroundStyle(.secondary),
              at: CGPoint(x: size.width / 2, y: size.height / 2))
          }
        }.contentShape(Rectangle()).gesture(
          SpatialTapGesture().onEnded { value in
            let points = locations(geo.size)
            if let index = points.indices.min(by: {
              hypot(points[$0].x - value.location.x, points[$0].y - value.location.y)
                < hypot(points[$1].x - value.location.x, points[$1].y - value.location.y)
            }) {
              store.selectedNode = index
            }
          }
        ).accessibilityLabel(
          "\(store.experiment.rule.count) nodes, step \(store.selectedStep). Click to select a node."
        )
      }
      HStack {
        Stepper(
          "Selected node: \(store.selectedNode+1)", value: $store.selectedNode,
          in: 0...(store.state.count - 1)
        ).fixedSize()
        Text(store.state[store.selectedNode].abbreviated(22)).font(
          .system(.body, design: .monospaced)
        ).textSelection(.enabled)
        Spacer()
        Menu("This step…") {
          Button("Copy vector", action: store.copyVector)
          Button("Use as new initial state", action: store.branch)
        }
      }
    }.padding(20)
  }
}

struct HeatmapView: View {
  @ObservedObject var store: LabStore
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Columns: nodes · rows: time").font(.callout)
        Spacer()
        Toggle("Scale each row independently", isOn: $store.heatPerRow).toggleStyle(.checkbox).font(
          .caption)
      }
      GeometryReader { geo in
        let rows = min(store.experiment.states.count, 180)
        let n = store.experiment.rule.count
        Canvas { context, size in
          let left: CGFloat = 43
          let top: CGFloat = 22
          let w = (size.width - left - 8) / CGFloat(n)
          let h = (size.height - top - 20) / CGFloat(max(1, rows))
          let maxLog = max(1, store.experiment.peaks.max() ?? 1)
          for row in 0..<rows {
            let t =
              rows == 1
              ? 0
              : Int((Double(row) * Double(store.experiment.lastStep) / Double(rows - 1)).rounded())
            let values = store.experiment.states[t]
            let scale = store.heatPerRow ? max(1, store.experiment.peaks[t]) : maxLog
            for i in 0..<n {
              let value = values[i]
              let color = value.signum > 0 ? teal : value.signum < 0 ? negative : Color.secondary
              let opacity = value.signum == 0 ? 0.07 : 0.18 + 0.8 * value.logMagnitude / scale
              context.fill(
                Path(
                  CGRect(
                    x: left + CGFloat(i) * w, y: top + CGFloat(row) * h, width: max(0.5, w - 0.7),
                    height: max(0.5, h - 0.5))), with: .color(color.opacity(opacity)))
            }
          }
          let y =
            top
            + (store.experiment.lastStep == 0
              ? 0
              : CGFloat(store.selectedStep) / CGFloat(store.experiment.lastStep) * CGFloat(rows - 1))
            * h
          context.stroke(
            Path(CGRect(x: left - 1, y: y, width: size.width - left - 7, height: max(1, h))),
            with: .color(.primary), lineWidth: 1)
          for i in [0, n / 2, n - 1] {
            context.draw(
              Text("\(i+1)").font(.system(size: 11)).foregroundStyle(.secondary),
              at: CGPoint(x: left + (CGFloat(i) + 0.5) * w, y: 8))
          }
          for t in [0, store.experiment.lastStep / 2, store.experiment.lastStep].uniqued() {
            let yy =
              top
              + (store.experiment.lastStep == 0
                ? 0 : CGFloat(t) / CGFloat(store.experiment.lastStep)) * CGFloat(max(0, rows - 1))
              * h
            context.draw(
              Text("\(t)").font(.system(size: 11)).foregroundStyle(.secondary),
              at: CGPoint(x: 32, y: yy + max(5, h / 2)), anchor: .trailing)
          }
        }.contentShape(Rectangle()).gesture(
          SpatialTapGesture().onEnded { v in
            let x = (v.location.x - 43) / max(1, geo.size.width - 51)
            let y = (v.location.y - 22) / max(1, geo.size.height - 42)
            store.selectedNode = max(0, min(n - 1, Int(x * CGFloat(n))))
            let row = max(0, min(rows - 1, Int(y * CGFloat(rows))))
            store.select(
              rows == 1
                ? 0
                : Int(
                  (Double(row) * Double(store.experiment.lastStep) / Double(rows - 1)).rounded()))
          }
        ).accessibilityLabel(
          "Node-time heatmap. Positive values are teal, negative values orange; intensity is logarithmic magnitude."
        )
      }
      HStack {
        Text("Intensity: log₁₀(1+|x|) · \(min(store.experiment.states.count,180)) sampled rows")
          .foregroundStyle(.secondary)
        Spacer()
        Text(
          "Step \(store.selectedStep), x\(store.selectedNode+1) = \(store.state[store.selectedNode].abbreviated(22))"
        )
      }.font(.caption)
    }.padding(20)
  }
}

struct PlotView: View {
  @ObservedObject var store: LabStore
  @State private var comparison = false
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Picker("Plot", selection: $comparison) {
          Text("Node values").tag(false)
          Text("Growth comparison").tag(true)
        }.pickerStyle(.segmented).frame(maxWidth: 400)
        Spacer()
        if !comparison {
          Toggle("Log scale", isOn: $store.signedLog).toggleStyle(.checkbox).font(.caption)
        }
      }
      if comparison {
        PlotCanvas(
          series: [
            PlotSeries(
              name: "Current · " + store.name, values: store.experiment.peaks, color: palette[0])
          ]
            + store.references.enumerated().map {
              PlotSeries(
                name: $0.element.name, values: $0.element.experiment.peaks,
                color: palette[($0.offset + 1) % palette.count])
            }, yLabel: "log₁₀(1 + max |x|)", selectedStep: store.selectedStep, select: store.select)
        HStack {
          Text("References may use different initial states and rules; check their labels.").font(
            .caption
          ).foregroundStyle(.secondary)
          Spacer()
        }
        ForEach(store.references) { reference in
          HStack {
            Text(reference.name).font(.caption)
            Text(reference.experiment.rule.shortName).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Remove") {
              store.references.removeAll { $0.id == reference.id }
              store.saveAutomatic()
            }.font(.caption)
          }
        }
      } else {
        let indices =
          store.showAllNodes && store.experiment.rule.count <= 12
          ? Array(0..<store.experiment.rule.count) : [store.selectedNode]
        let forceLog = (store.experiment.peaks.max() ?? 0) > 300
        let logarithmic = store.signedLog || forceLog
        PlotCanvas(
          series: indices.enumerated().map { offset, i in
            PlotSeries(
              name: "x\(i+1)",
              values: store.experiment.states.map {
                logarithmic ? $0[i].signedLog : $0[i].approximate
              }, color: palette[offset % palette.count])
          },
          yLabel: logarithmic
            ? "signed log₁₀(1+|x|)\(forceLog && !store.signedLog ? " · automatic for large numbers" : "")"
            : "Value (approximate display)", selectedStep: store.selectedStep, select: store.select)
        HStack {
          Toggle("All nodes (up to 12)", isOn: $store.showAllNodes).toggleStyle(.checkbox)
          Spacer()
          Stepper(
            "Node \(store.selectedNode+1)", value: $store.selectedNode,
            in: 0...(store.state.count - 1)
          ).fixedSize()
        }.font(.caption)
      }
    }.padding(20)
  }
}
struct PlotSeries {
  var name: String
  var values: [Double]
  var color: Color
}
struct PlotCanvas: View {
  var series: [PlotSeries]
  var yLabel: String
  var selectedStep: Int
  var select: (Int) -> Void
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(yLabel).font(.caption).foregroundStyle(.secondary)
      GeometryReader { geo in
        Canvas { context, size in
          let left: CGFloat = 65
          let right: CGFloat = 16
          let top: CGFloat = 15
          let bottom: CGFloat = 30
          let w = max(1, size.width - left - right)
          let h = max(1, size.height - top - bottom)
          let count = max(1, series.map { $0.values.count - 1 }.max() ?? 1)
          let all = series.flatMap(\.values).filter(\.isFinite)
          let scale = max(1, all.map { abs($0) }.max() ?? 1)
          let minV = min(0, (all.min() ?? 0) / scale)
          let maxV = max(1 / scale, (all.max() ?? 1) / scale)
          let span = max(1, maxV - minV)
          func position(_ i: Int, _ v: Double) -> CGPoint {
            CGPoint(
              x: left + CGFloat(i) / CGFloat(count) * w,
              y: top + h - CGFloat((v / scale - minV) / span) * h)
          }
          for tick in 0...4 {
            let v = minV + span * Double(tick) / 4
            let actual = v * scale
            let y = top + h - CGFloat((v - minV) / span) * h
            var line = Path()
            line.move(to: CGPoint(x: left, y: y))
            line.addLine(to: CGPoint(x: left + w, y: y))
            context.stroke(line, with: .color(.primary.opacity(0.1)), lineWidth: 1)
            context.draw(
              Text(String(format: "%.3g", actual)).font(.system(size: 11)).foregroundStyle(
                .secondary), at: CGPoint(x: left - 7, y: y), anchor: .trailing)
          }
          for tick in 0...4 {
            let t = Int(Double(count) * Double(tick) / 4)
            context.draw(
              Text("\(t)").font(.system(size: 11)).foregroundStyle(.secondary),
              at: CGPoint(x: left + CGFloat(t) / CGFloat(count) * w, y: top + h + 17))
          }
          for (idx, s) in series.enumerated() {
            let step = max(1, s.values.count / 900)
            var path = Path()
            var began = false
            var samples = Array(stride(from: 0, to: s.values.count, by: step))
            if let last = s.values.indices.last, samples.last != last { samples.append(last) }
            for i in samples {
              let point = position(i, s.values[i])
              if !began {
                path.move(to: point)
                began = true
              } else {
                path.addLine(to: point)
              }
            }
            context.stroke(
              path, with: .color(s.color),
              style: StrokeStyle(
                lineWidth: 1.8, dash: idx >= 10 ? [2, 2] : idx >= 5 ? [5, 3] : []))
            if s.values.count == 1 {
              let p = position(0, s.values[0])
              context.fill(
                Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)),
                with: .color(s.color))
            }
          }
          let x = left + CGFloat(selectedStep) / CGFloat(count) * w
          var marker = Path()
          marker.move(to: CGPoint(x: x, y: top))
          marker.addLine(to: CGPoint(x: x, y: top + h))
          context.stroke(
            marker, with: .color(.primary.opacity(0.4)),
            style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }.contentShape(Rectangle()).gesture(
          SpatialTapGesture().onEnded { v in
            let maxStep = max(1, series.map { $0.values.count - 1 }.max() ?? 1)
            select(
              Int(((v.location.x - 65) / max(1, geo.size.width - 81) * CGFloat(maxStep)).rounded()))
          }
        ).accessibilityLabel(
          "\(yLabel), horizontal axis: step. \(series.map(\.name).joined(separator:", "))")
      }
      HStack {
        Text("Time / step").font(.caption).foregroundStyle(.secondary)
        Spacer()
      }
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 14) {
          ForEach(Array(series.enumerated()), id: \.offset) { i, s in
            HStack(spacing: 5) {
              Circle().fill(s.color).frame(width: 7, height: 7)
              Text(s.name).font(.caption).lineLimit(1)
            }
          }
        }
        Text(series.map(\.name).joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
      }
    }
  }
}

struct ExactTable: View {
  @ObservedObject var store: LabStore
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Step \(store.selectedStep) · exact values").font(.headline)
        Spacer()
        Button("Copy vector", action: store.copyVector)
      }
      ScrollView([.horizontal, .vertical]) {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(store.state.indices, id: \.self) { i in
            HStack(alignment: .top, spacing: 16) {
              Text("x\(i+1)").font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
                .frame(width: 55, alignment: .leading)
              Text(store.state[i].description).font(.system(.body, design: .monospaced))
                .textSelection(.enabled).fixedSize(horizontal: true, vertical: false)
              Spacer(minLength: 0)
            }.padding(.vertical, 10)
            Divider()
          }
        }.frame(minWidth: 550, alignment: .leading)
      }
      Text("Plots may use approximate projections; this table and CSV preserve exact integers.")
        .font(.caption).foregroundStyle(.secondary)
    }.padding(20)
  }
}

struct BinaryScanView: View {
  @ObservedObject var store: LabStore
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text("Scan every binary initial state").font(.title3.weight(.medium))
        Text(
          "This scan uses the classic absolute-difference rule: a ring, offset 1, clockwise neighbors, and simultaneous updates. It is independent of the custom rule on the left."
        ).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        HStack {
          Stepper("Nodes: \(store.scanCount)", value: $store.scanCount, in: 2...18).fixedSize()
          Text("\(1 << store.scanCount) initial states").foregroundStyle(.secondary)
          Spacer()
          if store.scanning { ProgressView().controlSize(.small) }
          Button("Run exhaustive scan", action: store.startScan).buttonStyle(.borderedProminent)
            .disabled(store.scanning)
        }
        if let result = store.scan {
          Divider()
          Text("n = \(result.count) · \(result.states) initial states scanned").font(.headline)
          ForEach(result.cycleCounts.keys.sorted(), id: \.self) { period in
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text("Period \(period)").font(.headline)
                let cycleCount = result.cycleCounts[period]!
                Text(
                  "\(cycleCount) distinct \(cycleCount == 1 ? "cycle" : "cycles") · \(result.basinCounts[period] ?? 0) initial states"
                ).font(.caption).foregroundStyle(.secondary)
              }
              Spacer()
              Button("Open example cycle") { store.loadWitness(period: period) }
            }.padding(.vertical, 6)
          }
          let nonzero = result.cycleCounts.keys.filter { $0 > 1 }.sorted()
          Text(
            nonzero.isEmpty
              ? "Every initial state of this length reaches zero."
              : nonzero.count == 1
                ? "All nonzero cycles have the same period."
                : "\(nonzero.count) distinct nonzero periods."
          ).foregroundStyle(teal)
          Text(
            "This is an exhaustive calculation only for n = \(result.count). It is not a proof of the conjecture for all odd lengths."
          ).font(.caption).foregroundStyle(.secondary)
          Button("Copy scan results") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result.summary, forType: .string)
          }
        }
        Spacer(minLength: 20)
      }.padding(24)
    }
  }
}
extension Array where Element: Hashable {
  fileprivate func uniqued() -> [Element] {
    var seen = Set<Element>()
    return filter { seen.insert($0).inserted }
  }
}
