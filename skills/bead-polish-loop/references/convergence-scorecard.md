# Convergence Scorecard

Load this file when deciding whether to keep polishing.

Before scoring, check for red flags:

- oscillation between two graph shapes
- graph growth that adds complexity without clarifying ownership
- plateau at obviously low quality

If any of those dominate the round, reframe instead of trusting the score.

Score these three signals from `0.0` to `1.0`.

## 1. Output size shrinking (weight `0.35`)

Ask:

- are round summaries getting shorter?
- are fewer beads needing major rewrites?

Guide:

- `0.0`: still expanding a lot
- `0.5`: mixed
- `1.0`: clearly shrinking

## 2. Change velocity slowing (weight `0.35`)

Ask:

- are structural edits becoming less frequent?
- are new critical findings dropping?
- is dependency surgery becoming rarer?

Guide:

- `0.0`: major graph surgery is still happening
- `0.5`: moderate cleanup is still happening
- `1.0`: mostly corrective edits only

## 3. Content similarity increasing (weight `0.30`)

Ask:

- do successive rounds mostly agree on the graph shape?
- are you confirming the same stable structure instead of repeatedly reframing it?

Guide:

- `0.0`: oscillating or reframing repeatedly
- `0.5`: partial stability
- `1.0`: strong stability

## Weighted score

```text
score = 0.35 * size + 0.35 * velocity + 0.30 * similarity
```

## Decision guide

- `< 0.50`: not close; keep iterating
- `0.50 - 0.74`: improving, but not launch-ready by convergence alone
- `0.75 - 0.89`: usually good enough if coverage, dependency shape, and bead quality also pass
- `>= 0.90`: likely at diminishing returns

## Interpretation notes

- A high score does not excuse missing coverage, weak verification, or unresolved graph bottlenecks.
- Two consecutive rounds with scores above `0.75` and only corrective edits are a strong stop signal.
