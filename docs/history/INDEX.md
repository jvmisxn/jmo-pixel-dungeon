# Historical Index

## Purpose

This index makes the large archive files easier to navigate without re-reading all of them.

## Files

## `AUDIT_LOG.md`

- Best for: category-by-category audits, missing features, incorrect behavior, recommended fixes.
- Main content:
  - gameplay mechanics
  - AI and mob behavior
  - level generation
  - items and equipment
  - UI and HUD
  - audio and polish
  - buffs and effects
  - art and sprites
  - FOV and rendering
  - NPCs and quests
  - GDScript quality
- Use when:
  - you need rationale behind a previously identified issue
  - you want to know whether a system was audited already
  - you need deferred TODOs that were explicitly noted

## `FIX_LOG.md`

- Best for: chronological debugging history and concrete bug-fix sessions.
- Main content:
  - blank-map diagnosis
  - sprite and movement fixes
  - auto-walk and pathfinding
  - scene tree and actor lifecycle bugs
  - truncated-file recovery
  - missing method recovery
  - persistence and disk-sync issues
- Use when:
  - you need the root cause of a historical regression
  - you are touching a system known to have been unstable
  - you want to understand earlier emergency repairs

## `PROGRESS.md`

- Best for: broad project inventory and claims about implemented systems.
- Main content:
  - phase summaries
  - major integration passes
  - system inventories for items, actors, rendering, UI, and polish
- Use when:
  - you need a broad catalog of what exists
  - you want the previous high-level framing of the project
- Caution:
  - some sections describe intent or claimed completion more strongly than the present code may justify

## `CRITICAL_FIXES.md`

- Best for: short priority list of critical gameplay, AI, generation, UI, audio, and item fixes.
- Main content:
  - numbered issue list with fixed/unfixed status
- Use when:
  - you need a quick scan of historically high-priority problems

## `REMAINING_WORK.md`

- Best for: roadmap-style backlog and future planning.
- Main content:
  - known gaps
  - multiplayer direction
  - web export notes
  - testing recommendations
- Use when:
  - planning larger milestones
  - checking longer-term gaps rather than immediate bugs

## Suggested Read Order

1. `docs/memory/active-context.md`
2. `docs/memory/change-log.md`
3. `docs/memory/architecture-map.md`
4. `SUMMARY.md`
5. Specific archive file(s) from this folder as needed
