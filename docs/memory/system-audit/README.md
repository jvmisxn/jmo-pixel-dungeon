# System Audit Loop

A methodical, resumable pass over every system in the codebase. Each iteration
takes the next `pending` system from `ledger.md`, evaluates it deeply, researches
improvements, and records structured findings — **without editing game code**.
Implementation of any finding is a separate, gated step.

## Why this exists

The port is broad and playable but not yet hardened or framework-clean. Instead of
ad-hoc fixes, this loop walks the whole surface area once, systematically, so we get
a complete picture of debt, optimization opportunities, and worthwhile additions
before committing to bigger changes.

## What one iteration does

1. Read `ledger.md`, pick the highest-priority `pending` system.
2. Deep-read that system's files in full (respect the no-truncation rule; these are
   read-only during audit anyway).
3. Research three axes:
   - **Improvements** — correctness, SPD fidelity, robustness, save/load safety, coupling.
   - **Optimizations** — perf, allocations, redundant work, autoload dependency reduction.
   - **Additions** — missing SPD features, framework-extraction hooks, tests.
4. Web-research where it helps (Godot 4.5 GDScript best practices, original SPD behavior).
5. Write a findings report to `reports/<id>-<name>.md` using the template below.
6. Append the concrete, actionable items to the repo `docs/memory/backlog.md`
   (tagged `[audit:<id>]`), most valuable first.
7. Mark the system `done` in `ledger.md` and record the report link + one-line verdict.

## Rules

- **Audit = read + research + record. No game-code edits inside the loop.**
- Findings are recommendations. Nothing gets implemented without explicit go-ahead.
- Prefer high-signal findings over exhaustive nitpicks. Rank by value.
- Respect `docs/memory/` conventions: compact, durable, searchable.
- Files in `TRUNCATED_FILES.txt` are high-risk — flag but never edit during audit.

## Report template

```md
# <System> — Audit

- Files: <paths>
- Read in full: yes/no (note any skipped)
- Verdict: <one line: healthy / needs-hardening / fragile / thin>

## Improvements
- [P?] <finding> — <why it matters> — <suggested direction>

## Optimizations
- [P?] <finding> — <impact>

## Additions
- [P?] <finding> — <value / SPD parity ref>

## Save/load & coupling notes
- <persistence contract state, autoload dependencies>

## Research notes
- <sources consulted, SPD reference points>
```

Priority tags: P0 (correctness/data-loss), P1 (high value), P2 (nice), P3 (optional).
