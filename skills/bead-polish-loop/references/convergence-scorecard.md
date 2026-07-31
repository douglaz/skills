# Convergence Scorecard

Load this file when deciding whether to keep polishing.

Before scoring, update the findings ledger and coverage checklist.

Do not allow convergence if any of these are still true:

- the minimum pass budget has not been met
- any epic is still unreviewed
- any `P0` or `P1` bead is still unreviewed
- any critical-path bead is still unreviewed
- any critical findings ledger item is still unresolved

Before scoring, check for red flags:

- oscillation between two graph shapes
- graph growth that adds complexity without clarifying ownership
- plateau at obviously low quality

If any of those dominate the round, reframe instead of trusting the score.

Score these four signals from `0.0` to `1.0`.

## 1. Coverage completeness (weight `0.30`)

Ask:

- have you actually reviewed the whole important surface, not just the easiest subset?
- have all epics, `P0`/`P1`, and critical-path beads been inspected?
- have the weak areas from prior rounds been revisited after edits?

Guide:

- `0.0`: coverage is patchy or concentrated in one corner of the graph
- `0.5`: most important areas were reviewed, but some notable gaps remain
- `1.0`: all important surfaces were reviewed and revisited as needed

## 2. Unresolved findings shrinking (weight `0.25`)

Ask:

- is the findings ledger clearly shrinking?
- are critical findings disappearing instead of just being restated?
- are new findings still being discovered in important areas?

Guide:

- `0.0`: findings are still growing or not being closed
- `0.5`: some findings are closing, but important ones remain
- `1.0`: only minor leftovers remain or the ledger is empty

## 3. Change velocity slowing (weight `0.25`)

Ask:

- are structural edits becoming less frequent?
- are new critical findings dropping?
- is dependency surgery becoming rarer?

Guide:

- `0.0`: major graph surgery is still happening
- `0.5`: moderate cleanup is still happening
- `1.0`: mostly corrective edits only

## 4. Graph shape stability (weight `0.20`)

Ask:

- do successive rounds mostly agree on the graph shape?
- are you confirming the same stable structure instead of repeatedly reframing it?

Guide:

- `0.0`: oscillating or reframing repeatedly
- `0.5`: partial stability
- `1.0`: strong stability

## Weighted score

```text
score = 0.30 * coverage + 0.25 * findings + 0.25 * velocity + 0.20 * stability
```

## Decision guide

- `< 0.50`: not close; keep iterating
- `0.50 - 0.74`: improving, but not launch-ready by convergence alone
- `0.75 - 0.84`: close in some dimensions, but still below the stop threshold
- `0.85 - 0.94`: usually ready for the independent reviewer-panel handoff if the
  ledger is clear and the stop gates pass
- `>= 0.95`: likely at diminishing returns; hand off to the panel

## Interpretation notes

- A high score does not excuse missing coverage, weak verification, or unresolved graph bottlenecks.
- A high score is a polishing stop signal, not implementation approval. The
  default `second-model-bead-audit` panel still owns the launch verdict.
- If any critical findings ledger item remains open, cap the effective score at `0.74`.
- Two consecutive rounds with scores above `0.85`, only corrective edits, and a clear findings ledger are a strong stop signal.
