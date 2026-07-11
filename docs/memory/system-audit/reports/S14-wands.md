# Wands & staffs — Audit

- Files: `src/items/wands/wand.gd` (1087 lines — base `Wand` + all 13 wand subclasses in one file). No separate staff class exists; the Mage "staff" is handled via belongings/battlemage passives, not here.
- Read in full: yes
- Verdict: **fragile** — the defining mechanic (recharge over time) is unwired, and several subclasses have real behavioral bugs.

## Improvements

- [P0] **Wands never recharge over time.** `recharge()` (wand.gd:50) has *no per-turn caller* anywhere — grep of `.recharge(` finds only instantaneous triggers (scroll.gd, armor_glyph.gd, spell.gd). There is no Charger buff, and nothing in `turn_manager.gd` / `hero.gd` / `belongings.gd` ticks equipped wands. `Recharging` buff's `recharge_rate()` (recharging.gd:17) has zero callers, so Potion/effect of Recharging does nothing. Net: a wand starts with 2 charges and only ever refills from rare consumable procs. This breaks the system's core loop. — *Add a per-hero-turn Charger (SPD `Wand.Charger` buff on equip) that calls `recharge(1, hero)` each turn and multiplies by `Recharging.recharge_rate()` / battlemage multiplier.*
- [P1] **WandOfFrost always paralyzes.** wand.gd:425-433 adds `Cripple`, then immediately checks `has_buff("Cripple")` — which is now always true because it was just added — so `Paralysis` fires on every single frost hit. The freeze should only trigger if the target was *already* chilled before this zap. — *Capture `was_chilled = has_buff("Cripple")` before adding the new Cripple.*
- [P1] **Wand becomes un-identifiable by use after 5 zaps.** `_use_for_identification` (wand.gd:105) decrements both `_uses_left_to_id` (starts 10) and `_available_uses_to_id` (starts 5), and early-returns once `_available_uses_to_id <= 0`. `_available_uses_to_id` is never refilled, so after 5 zaps `_uses_left_to_id` is stuck at 5 and `identify()` is never reached. SPD refills `availableUsesToID` on level-up/descend. — *Wire a refill hook (on hero level/descend) or remove the availability gate.*
- [P1] **WandOfCorruption corrupts into an enemy, not an ally.** on_zap (wand.gd:1006-1012) sets `target_char.alignment = "ally"` (a *string*, but `ConstantsData.Alignment` is an int enum) and applies `Amok` — whose own doc says "attacks the nearest character **regardless of allegiance**" (amok.gd:3), i.e. the "corrupted" mob will attack the hero. There is already a purpose-built `CorruptionBuff` (corruption_buff.gd) that flips alignment properly. — *Use `CorruptionBuff.new()` instead of Amok + string assignment.* (Cross-system caveat: `mob.gd`/`char.gd` expose no `alignment` var or `set_alignment()`, so the whole ally-alignment path is likely inert — flag for S05/S21.)
- [P1] **WandOfDisintegration bypasses the damage pipeline.** wand.gd:571-574 mutates `target_char.hp` directly and calls `die()` manually instead of `take_damage()`. This skips shielding, `Invulnerable`/immunity/resist, ArcaneArmor, on-damage buff wakeups (Frozen/Sleep/Terror recover), and consistent death handling — all of which live in `Char.take_damage` (char.gd:242+). "Ignores armor" doesn't require bypassing the whole pipeline. — *Route through `take_damage`; if armor-ignore is needed, add a magic/ignore-DR flag to the damage path.*
- [P1] **WandOfWarding is fully inert.** on_zap (wand.gd:853-881) only tracks `_sentry_positions` and prints messages — no Sentry actor is ever spawned, and nothing zaps enemies. It's a no-op wand. — *Spawn an actual ward/Sentry mob (SPD `Wand.WardParticle` / `WardSentry`) that attacks in range.*

## Optimizations

- [P2] `roll_zap_damage` uses uniform `randi_range` (wand.gd:166); SPD wands use `Random.NormalIntRange` (bell-curve). Same fidelity gap noted in S03. No shared helper exists (char.gd:229-234 hand-rolls a triangular approximation inline). — *Extract a `Balance.normal_int_range(min,max)` helper and use it in wands, char DR, and weapons.*
- [P2] Chain lightning re-rolls damage per arc and applies a `0.7^n` falloff (wand.gd:486,492); SPD lightning deals full damage to every affected target with no falloff. Also `_find_nearest_char` (wand.gd:508) does an 81-cell `find_char_at` scan per arc (up to `3+level` arcs). — *Match SPD (full damage, arc within 2 tiles) and iterate the level's mob list instead of a grid scan.*
- [P2] `_make_open_passable()` allocates a fresh `ConstantsData.LENGTH` bool array on every disintegration zap and every fallback zap (wand.gd:132, 560). — *Cache or pass the level's real passable array.*
- [P2] Frost/Corrosion use `Cripple`/`Poison` stand-ins and apply instantly; SPD Corrosion is a spreading gas Blob and Frost applies a real Chill/Frost. — *Wire the corrosion gas Blob (see S20) and dedicated Chill buff for parity.*

## Additions

- [P1] Per-turn Charger + wire the `Recharging` buff and battlemage recharge multiplier (see P0).
- [P2] Persist a `Charger`/recharge cadence so partial charge survives save/load consistently (`_recharge_progress` is already serialized, wand.gd:262).
- [P3] Real Sentry mob for Warding; corrosion gas Blob; dedicated Chill/Frost buff.
- [P3] Unit tests for the recharge formula (`BASE + SCALING * scale^missing`), `random()` upgrade distribution (66.7/26.7/6.7), and the frost "already-chilled" gate.

## Save/load & coupling notes

- Serialization is solid: base `Wand.serialize/deserialize` covers charges, max, `_recharge_progress`, cursed_effect, and both id counters; subclasses with extra state (LivingEarth `_guardian_shield`, Warding `_sentry_positions`) override correctly. Factory `create()` (wand.gd:282) dispatches all 13 IDs.
- Heavy runtime coupling via `has_method`/`get` duck-typing to the level (`find_char_at`, `get/set_terrain`, `is_passable`) and to buff classes — resilient but hides the missing-alignment problem above.
- `upgrade()` (wand.gd:190) correctly reproduces SPD's 33%-chance curse removal and +1-charge-on-upgrade; `random()` distribution is faithful.

## Research notes

- SPD `Wand.Charger` is a per-turn `Buff` attached on equip; `partialCharge += (1/turnsToCharge) * RingOfEnergy/scaling multipliers`. The repo has the *formula* (wand.gd:50-69) but not the *buff that calls it every turn* — that's the P0.
- SPD `availableUsesToID` is refilled on hero level-up/descend, which is why partial-ID doesn't permanently stall in the original.
- SPD Wand of Corruption replaces the mob's AI with an ally `Corruption` state (no direct damage) — matches the repo's own unused `CorruptionBuff`, not `Amok`.
- No auto-fixes this run: `wand.gd` is in `TRUNCATED_FILES.txt`, and every finding is behavioral (not a mechanical no-behavior-change edit). All left in the backlog for approval.
