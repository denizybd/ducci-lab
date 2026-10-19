# User guide

## Initial state

Choose 2–128 nodes. Enter one integer per node, separated by commas, spaces, semicolons, or new lines. The **Generate** menu supplies random binary values, random integers from −9 to 9, or one 1 surrounded by zeros.

The presets menu offers classic absolute difference, signed difference, a mod-2 neighbor sum, a nine-node ring, and a 17-node binary example with period 85. A preset's name is a label, not a prediction for initial values entered afterward; read **Cycle** for the actual result.

## Rule and neighborhood

```text
value = a·self + b·neighbor + c
value = |value|          if absolute value is enabled
value = value mod m      if modular arithmetic is enabled
```

Modular residues are nonnegative. Classic Ducci uses `a=1`, `b=−1`, `c=0`, absolute value enabled, and modulo disabled.

The selected neighbor is `offset` positions clockwise/forward or counterclockwise/backward. Offset 0 selects the node itself.

| Topology | Behavior outside the node range |
|---|---|
| Ring | Wrap around |
| Zero outside | Use zero |
| Clamp at ends | Use the closest endpoint |
| Reflect at ends | Mirror without repeating the endpoint |

For three nodes with zero-based indices, reflection maps −1 to 1 and 3 to 1.

**Simultaneous** updates read every value from the previous state. **In-place** sweeps write each new value immediately; later nodes can read it. One step always updates all nodes once.

Draft settings do not alter existing history. Click **Apply new experiment** to start with the edited settings.

## Time and cycles

- **Advance** moves by the selected number of steps; **+100 steps** calculates a batch.
- **Play/Pause** runs at the selected rate, measured in advances per second.
- The slider and step field select recorded states. Going backward reads history; it does not invert the rule.
- New calculations append at the end. Scrubbing backward does not erase later states.
- **Stop at the first repeated state** pauses on an exact repeat. Disable it to continue following a cycle.

Step 0 is the initial state. A cycle beginning at step `s` with period `p` first repeats at `s+p`. The cycle status describes generated history even when an earlier step is selected.

Shortcuts: **⌘R** toggles playback, **⌘→** advances, **⌘O** opens a recipe, **⌘S** saves, and **⌘E** exports CSV.

## Views

### Ring / topology

Arrows point to the neighbor a node reads. Teal means positive, orange negative, and a faint node zero. Click a node or use **Selected node**. Values are shortened on crowded nodes; **Exact values** contains complete numbers.

**This step…** copies the vector or uses it as a new initial state. Pin or save a run before branching to retain it.

### Time map

Columns are nodes and rows are time. Intensity encodes `log10(1+|x|)`. Scale all rows together or each row independently. Up to 180 rows are sampled; clicking selects the actual recorded step. CSV contains every generated state.

### Plots

**Node values** plots all nodes for systems of up to 12 nodes, or a selected node for larger systems. Signed log scale uses `sign(x)·log10(1+|x|)`. Linear projections are approximate; sufficiently large values automatically use log scale.

**Growth comparison** plots `log10(1+max|x|)` for the current run and up to four pinned references. References may have different rules and initial states. Long histories are sampled for drawing; stored values remain exact.

### Exact values

Shows every complete integer at the selected step. Copy individual numbers or the whole vector, or export CSV.

### Binary scan

Enumerates every binary initial state for `n=2…18` using the **classic absolute-difference ring**, offset 1, clockwise, with simultaneous updates. It is independent of custom rule settings.

For each period it reports the number of distinct cycles and the number of initial states that reach those cycles, including transients. Open an example to inspect it. The zero cycle has period 1.

## Saving and sharing

**Save…** exports a JSON recipe containing the rule, initial state, generated step count, selected step, and pinned references. **Open…** regenerates trajectories from those recipes. **CSV…** exports complete history with columns `step,x1,x2,…` and exact decimal integers.

The last experiment is autosaved in `~/Library/Application Support/DucciLab/last-experiment.json`. Version 1.1 accepts version 1.0's Turkish boundary and update-order identifiers and writes stable English identifiers. User-authored names are preserved. Version 1.0 does not understand the newer identifiers.

## Limits

| Item | Limit |
|---|---|
| Nodes | 2–128 |
| Neighbor offset | 0–127 |
| Coefficients a, b | −1000…1000 |
| Constant c | −1,000,000…1,000,000 |
| Modulus | 2…1,000,000,000 |
| Initial integer length | 1,000 decimal digits per value |
| Calculated integer length | 2,000 decimal digits per value |
| History | Up to 10,000 steps |
| Stored node values | 250,000 per experiment |
| Stored decimal digits | 2,000,000 per experiment |
| Comparison references | 4 |
| Exhaustive binary scan | 2–18 nodes |

Reaching a limit stops calculation and preserves existing results. Values are never silently reduced, wrapped, or rounded to keep a simulation running.
