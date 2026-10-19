# Mathematical notes

## Classic Ducci

For a cyclic integer vector `x=(x₁,…,xₙ)`, the classic map is `D(x)ᵢ=|xᵢ−xᵢ₊₁|`, where `xₙ₊₁=x₁`. All nodes update simultaneously.

```text
(1,0,0) → (1,0,1) → (1,1,0) → (0,1,1) → (1,0,1)
```

The transient length is 1 and the period is 3. Rotating a vector does not make it the same state for cycle detection.

Integer trajectories eventually reach cycles with entries in `{0,c}` for a common constant `c`, which need not equal 1. Every integer initial state reaches zero exactly when the number of nodes is a power of two; other lengths can have nonzero cycles. These are established results.

## Finite scans

The core checks exhaustively verify:

| Nodes | Period → number of distinct cycles |
|---|---|
| 3 | 1 → 1, 3 → 1 |
| 5 | 1 → 1, 15 → 1 |
| 9 | 1 → 1, 3 → 1, 63 → 4 |
| 17 | 1 → 1, 85 → 3, 255 → 256 |

These calculations do not prove statements for every length. Being prime is not sufficient for all nonzero cycles to share one period: 17 has periods 85 and 255.

[OEIS A138004](https://oeis.org/A138004) records a conjecture in the other direction: an odd length greater than 1 for which all nonzero binary cycles share one period must be prime. Check current literature before treating related questions as new or unresolved.

## Signed differences

With absolute value disabled, `L(x)ᵢ=xᵢ−xᵢ₊₁`. The sum of the entries becomes zero after one step. For three nodes with `a+b+c=0`:

```text
L²(a,b,c) = (−3b,−3c,−3a)
L⁶(a,b,c) = −27(a,b,c)
```

For four nodes, `(1,−1,1,−1)` doubles each step. For six nodes, `(1,1,0,−1,−1,0)` repeats after six steps without growing. Initial structure matters as well as node count.

Writing `L=I−S`, where `S` is cyclic shift, gives Fourier-mode magnitude multipliers `2|sin(πk/n)|`. This linear analysis does not apply unchanged to the absolute-value map.

## Transition time

Fast reduction to two levels is not a uniform bound on the transient. Under the classic rule, `(0,1,M)` reaches a binary cycle at step `M` for integers `M≥2`.

For 17 nodes, `(0,1,1000)` followed by 14 zeros reaches a binary cycle after 511 steps; replacing 1000 with 10000 increases that to 3886 steps. Both resulting periods are 255.

The first two-level step, the cycle-entry step, and the cycle period are different measurements. Proposed research should specify the rule, input family, and sampling distribution, and be checked against existing work.

## Variants

Adding the same constant to every initial entry disappears after one classic step. Scaling an initial vector scales its subsequent trajectory. Visually different experiments may therefore share the same structure.

For a ring with neighbor offset `k`, node connections split into `gcd(n,k)` independent cycles under simultaneous updating. Changing boundaries, update order, coefficients, or absolute-value semantics can produce a different system.

The mod-2 neighbor-sum preset agrees with absolute difference on binary states. Modular sums with larger moduli are a related variant, not the same integer absolute-difference map.

## References

- [Creely: The Length of a Three-Number Game](https://www.fq.math.ca/Scanned/26-2/creely.pdf).
- [Breuer and Shparlinski: Lower bounds for periods of Ducci sequences](https://arxiv.org/abs/1909.04462).
- [Lewis and Tefft: Values of Ducci Periods for Sequences on Zₘⁿ](https://arxiv.org/abs/2502.03348).
- [Brockman: Asymptotic behavior of certain Ducci sequences](https://web.mit.edu/gdb/www/pdfs/asymptotic-behavior.pdf).
- [MIT: Eigenvectors of circulant matrices](https://web.mit.edu/18.06/www/Spring17/Circulant-Matrices.pdf).
