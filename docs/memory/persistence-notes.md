# Persistence Notes

## Why This Matters

- Persistence is one of the highest-risk structural areas in the project.
- Historical work repeatedly touched save/load, level caching, and entity reconstruction.
- Even when the game is playable, persistence issues can silently poison framework reuse.

## Practical Rules

- Any change to hero, level, mobs, items, buffs, quests, or floor transitions should trigger a save/load review.
- Do not assume historical "fixed" status is still correct without checking current code paths.
- Prefer explicit serialization contracts over `has_method()`-guarded best-effort behavior when hardening systems.

## What To Watch

- cold-start continue flow
- level backtracking cache
- boss/final/special level serialization behavior
- equipped item restoration
- quest and NPC state restoration
- turn manager / actor reactivation after load

## Good Search Terms

- `serialize`
- `deserialize`
- `save_full_game`
- `level_cache`
- `current_level`
- `hero`

## Working Stance

- Treat persistence as a system to verify deliberately, not a passive feature that will stay correct automatically.
