# Bead Polish Rubric

Load this file when scoring or rewriting beads.

Score each category `0`, `1`, or `2`.

## Categories

### 1. WHAT

- `0`: unclear or generic task wording
- `1`: roughly clear, but still broad or ambiguous
- `2`: concrete outcome or deliverable is clear

### 2. WHY

- `0`: no user, product, or operational reason stated
- `1`: reason is implied, but weak
- `2`: rationale and value are explicit

### 3. CONSTRAINTS / FAILURE HANDLING

- `0`: major constraints, risks, or failure paths are absent
- `1`: partial notes exist, but future agents still have to guess
- `2`: important interfaces, boundaries, and failure/recovery expectations are explicit

### 4. DEPENDENCIES / ORDERING

- `0`: ordering is implicit, missing, or wrong
- `1`: some sequencing hints exist, but they are incomplete
- `2`: dependencies are explicit and sensible

### 5. VERIFICATION

- `0`: no explicit validation path
- `1`: says "add tests" but lacks specifics
- `2`: names concrete unit, integration, e2e, or equivalent checks

### 6. OBSERVABILITY / OPERATIONS

- `0`: no diagnostics for work that obviously needs them
- `1`: vague mention of logs, metrics, or monitoring
- `2`: explicit diagnostics or operator hooks exist where relevant

### 7. BOUNDARIES / NON-GOALS

- `0`: bead could sprawl indefinitely
- `1`: partial boundaries exist
- `2`: scope and non-goals are clear

## Interpretation

- `12-14`: strong bead
- `9-11`: usable, but still worth tightening when the area matters
- `0-8`: rewrite before launch

## Rewrite priority

When time is limited, rewrite beads in this order:

1. low score + high priority
2. low score + on a critical dependency chain
3. low score + broad user-visible or operator-visible impact
4. everything else
