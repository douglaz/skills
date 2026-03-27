# Bead Polish Rubric

Load this file when scoring or rewriting beads.

Score each category 0, 1, or 2.

## Categories

### 1. WHAT
- 0: unclear or generic task wording
- 1: roughly clear, but still broad or ambiguous
- 2: concrete outcome or deliverable is clear

### 2. WHY
- 0: no user/product/operational reason stated
- 1: implied reason, but weak
- 2: clear rationale and value

### 3. HOW / KEY CONSTRAINTS
- 0: no guidance on important constraints or interfaces
- 1: partial notes, but future agents still have to guess
- 2: major constraints and tricky edges are explicit

### 4. DEPENDENCIES / ORDERING
- 0: ordering is implicit or wrong
- 1: some sequencing hints, but incomplete
- 2: dependencies are explicit and sensible

### 5. VERIFICATION
- 0: no explicit validation path
- 1: says "add tests" but lacks specifics
- 2: names concrete unit/integration/e2e or equivalent checks

### 6. OBSERVABILITY / OPERATIONS
- 0: no diagnostics for work that obviously needs them
- 1: vague mention of logs/monitoring
- 2: explicit logging, metrics, or diagnostics where relevant

### 7. BOUNDARIES / NON-GOALS
- 0: bead could sprawl indefinitely
- 1: partial boundaries
- 2: clear scope and non-goals

## Interpretation

- 12-14: strong bead
- 9-11: usable but should still be tightened if the area is important
- 0-8: rewrite before launch

## Rewrite priority

When time is limited, rewrite beads in this order:

1. low score + high priority
2. low score + on critical dependency chain
3. low score + broad user-visible impact
4. everything else
