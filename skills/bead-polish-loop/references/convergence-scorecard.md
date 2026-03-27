# Convergence Scorecard

Load this file when deciding whether to keep polishing.

Use three signals. Score each from 0.0 to 1.0.

## 1. Output size shrinking (weight 0.35)

Ask:
- are the round summaries getting shorter?
- are fewer beads needing major rewrites?

Guide:
- 0.0 = still expanding a lot
- 0.5 = mixed
- 1.0 = clearly shrinking

## 2. Change velocity slowing (weight 0.35)

Ask:
- are you making fewer structural changes each round?
- are new critical findings dropping?

Guide:
- 0.0 = major graph surgery still happening
- 0.5 = moderate cleanup still happening
- 1.0 = mostly corrective edits only

## 3. Content similarity increasing (weight 0.30)

Ask:
- do successive rounds mostly agree on the graph shape?
- are you seeing confirmation of the same stable structure rather than new rethinks?

Guide:
- 0.0 = oscillating or reframing repeatedly
- 0.5 = partial stability
- 1.0 = strong stability

## Weighted score

```text
score = 0.35 * size + 0.35 * velocity + 0.30 * similarity
```

## Decision guide

- `< 0.50`: not close; keep iterating
- `0.50 - 0.74`: improving, but still not launch-ready by convergence alone
- `0.75 - 0.89`: usually good enough if translation and quality gates pass
- `>= 0.90`: likely diminishing returns

## Red flags

Stop and reframe instead of polishing harder if you see:

- oscillation between two decompositions
- graph growth that keeps adding complexity without clarifying ownership
- plateau at obviously low quality
