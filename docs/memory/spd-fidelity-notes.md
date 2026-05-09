# SPD Fidelity Notes

## Scope

These notes are for work where matching original Shattered Pixel Dungeon behavior matters.

## Current Position

- Historical work already fixed many high-impact formula and behavior mismatches.
- Remaining fidelity work is now more about deeper systems and edge behavior than total mechanical absence.

## Major Remaining Fidelity Themes

- identification system
- talent system
- curse depth and cursed-item interactions
- advanced mob targeting/behavior logic
- deferred item/generator systems such as deck behavior

## Working Rules

- Do not trust old "missing feature" notes blindly; many were later fixed.
- When doing fidelity work, check:
  - `docs/memory/archive-backlog.md`
  - `docs/history/CRITICAL_FIXES.md`
  - `docs/history/AUDIT_LOG.md`

## Practical Distinction

- "Playable" is already achieved.
- "Faithful enough for customization baseline" still requires selecting which SPD systems are essential and which are optional.

## Recommended Use

- Use this note when deciding whether to prioritize strict SPD parity versus framework cleanup.
- If the answer affects long-term architecture, record the decision in `decisions.md`.
