# Active Context

## Current State

- The game is playable now.
- The codebase is broad and functional, with substantial systems already ported.
- The project is best treated as a playable port that still needs hardening before it becomes a clean reusable framework.
- Current milestone is `0.1.2`.
- Co-op multiplayer is now an active roadmap item, targeting online host-authoritative play for up to 4 players.
- Framework extraction for future spin-off games is now an active investigation track, with multiplayer hardening treated as part of that architectural work rather than a separate concern.

## Current Constraints

- Avoid bloated context reads when smaller memory notes are enough.
- Do not rely on `docs/history/PROGRESS.md` or `docs/history/AUDIT_LOG.md` as the first source of truth for day-to-day work.
- Preserve file integrity carefully; this repo has a history of truncation-related breakage.
- Large Claude-generated audit/fix logs remain valuable, but they should be consulted selectively.

## Known High-Value Risks

- Persistence/save-load contracts are not fully reliable across all runtime objects.
- Global autoload coupling is still high.
- Some systems are broad in coverage but not yet hardened enough for framework reuse.
- Mobile combat input and real-time pacing need real-device/windowed validation after `b0c8971`: confirm tap attacks no longer double-submit, damage numbers are not duplicated, and the restored `0.1s` visible-mob delay feels close to Shattered Pixel Dungeon.
- If duplicate damage numbers are still reported only in online/co-op, investigate snapshot HP-delta feedback echoing local combat feedback rather than re-opening the fixed single-player/mobile tap path.

## Working Assumptions

- Finish hardening the port before major framework extraction or multi-game branching.
- Prefer small durable notes over large historical narrative logs.
- Multiplayer should start with single-process multi-hero simulation before any network transport work.

## Next Time Start Here

1. Search `docs/memory/` for the relevant system.
2. Read the most recent `change-log.md` entries.
3. Read `archive-backlog.md` if the work sounds like an old deferred issue.
4. Only pull larger docs when the concise memory files are insufficient.

## Fast Topic Routing

- Save/load or floor-state work: read `persistence-notes.md`
- Architecture or reuse work: read `framework-readiness.md`
- Framework extraction planning: read `framework-extraction-roadmap.md`
- Original-SPD parity work: read `spd-fidelity-notes.md`
- Co-op multiplayer work: read `multiplayer-roadmap.md`
