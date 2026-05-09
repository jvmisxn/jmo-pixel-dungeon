# Active Context

## Current State

- The game is playable now.
- The codebase is broad and functional, with substantial systems already ported.
- The project is best treated as a playable port that still needs hardening before it becomes a clean reusable framework.

## Current Constraints

- Avoid bloated context reads when smaller memory notes are enough.
- Do not rely on `docs/history/PROGRESS.md` or `docs/history/AUDIT_LOG.md` as the first source of truth for day-to-day work.
- Preserve file integrity carefully; this repo has a history of truncation-related breakage.
- Large Claude-generated audit/fix logs remain valuable, but they should be consulted selectively.

## Known High-Value Risks

- Persistence/save-load contracts are not fully reliable across all runtime objects.
- Global autoload coupling is still high.
- Some systems are broad in coverage but not yet hardened enough for framework reuse.

## Working Assumptions

- Finish hardening the port before major framework extraction or multi-game branching.
- Prefer small durable notes over large historical narrative logs.

## Next Time Start Here

1. Search `docs/memory/` for the relevant system.
2. Read the most recent `change-log.md` entries.
3. Read `archive-backlog.md` if the work sounds like an old deferred issue.
4. Only pull larger docs when the concise memory files are insufficient.

## Fast Topic Routing

- Save/load or floor-state work: read `persistence-notes.md`
- Architecture or reuse work: read `framework-readiness.md`
- Original-SPD parity work: read `spd-fidelity-notes.md`
