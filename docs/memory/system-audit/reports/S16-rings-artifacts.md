# Rings & Artifacts — Audit

- Files: `src/items/rings/ring.gd` (754 lines), `src/items/artifacts/artifact.gd` (1686 lines)
- Read in full: yes (both). `artifact.gd` is in `TRUNCATED_FILES.txt` — flagged, not edited.
- Verdict: **needs-hardening** — buff/curve math is faithful, but equipped rings/artifacts
  lose all passive effect on save/load, four rings + one artifact are wired to hooks that
  are never called (Furor, Haste, Wealth, Force-unarmed, Cape of Thorns), and Ring of Might
  corrupts hero stats across a reload.

## Improvements

- [P1] **Equipped rings/artifacts go inert after any save/load.** `belongings.deserialize()`
  restores equip slots with a raw `set(slot_name, item)` "to avoid triggering gameplay effects"
  (`belongings.gd:391-402`), so `on_equip()` → `_apply_passive()` (`ring.gd:40-64`) never runs on
  load. The ring's `_passive_buff` stays `null`, and the passive `Buff` doesn't survive
  `_serialize_buffs`/`_deserialize_buffs` either: `Buff.serialize` keys on
  `get_script().resource_path` (`buff.gd:174-181`), which is empty for these inner-class buffs, so
  `_deserialize_buffs` skips them (`char.gd:466-468`) — and even if restored, the buff's `ring`
  back-reference isn't serialized, so every `modify_*` returns unchanged. Net: every equipped
  ring's effect is dead after a reload until the player manually re-equips. Direction: on load,
  route equipped items through the real equip path (or a `resolve_post_load()` that re-runs
  `_apply_passive`), and persist the ring↔buff link.

- [P1] **Ring of Might corrupts hero stats across save/load.** `MightBuff._apply_bonus()` mutates
  base `str_val`/`hp_max`/`ht` directly (`ring.gd:472-495`). Those inflated stats serialize; on
  load the buff is gone (see above) so the inflation persists with nothing to subtract it, and
  re-equipping adds the bonus *again* on top → cumulative STR/HP drift. Direction: apply STR/HT
  through modifier hooks (like the other rings) instead of writing base fields, so the bonus is
  always derived, never baked into saved state.

- [P1] **Rings of Furor and Haste are inert.** Both effects live in `modify_speed()`
  (`ring.gd:404-411`, `426-432`), but `Char.get_speed()` only consults named buffs
  (Cripple/Stamina/Adrenaline/"Haste"-the-spell) and never iterates `_buffs` calling
  `modify_speed()` (`char.gd:531-543`). Same dead-hook class already logged in S06. FurorBuff
  (`buff_id="RingOfFuror"`) and HasteBuff (`buff_id="RingOfHaste"`) are never seen → both rings do
  nothing. Direction: have `get_speed()` fold in `modify_speed()` from buffs (fixes S06 items too);
  additionally Furor should scale *attack* speed only and Haste *move* speed only — currently both
  multiply the single speed value identically.

- [P1] **Cape of Thorns is fully inert.** Its charge-gain, 50% absorb, and retaliation all live in
  `on_hero_damaged(damage, source)` (`artifact.gd:371-388`), which the damage pipeline never calls:
  `Char.take_damage` only runs herbal/barrier/shield absorb (`char.gd:207-316`), and the
  `on_hero_damaged` seen in `scene_feedback_coordinator.gd`/`game_scene.gd` is unrelated visual
  feedback. So the cape never charges (its `charge_rate = 0.0`, gain only from hits), never absorbs,
  never reflects. Direction: invoke the artifact hook from `take_damage` (artifact.gd is truncated —
  gate the wiring on the caller side / a non-truncated shim).

- [P1] **Ring of Wealth is fully inert.** `WealthBuff` carries no stat hook and no loot/gold code
  reads the wealth bonus — nothing in `generator.gd`, `heap.gd`, `game_manager.gd`, or `src/levels`
  queries `RingOfWealth`/`WealthBuff`/wealth `bonus()` (`ring.gd:554-565`). The gold-multiplier and
  rare-drop effect is dead content. Direction: query the equipped Wealth ring's `bonus()` in the
  gold/loot roll (SPD: scaling drop of gold + consumables/rings "wealth" pity counter).

## Optimizations

- [P2] **Ring buffs recompute `pow()` every combat query.** Accuracy/Evasion/Furor/Haste each call
  `pow(1.3^b)` / `pow(1.2^b)` on every `modify_*` invocation (`ring.gd:281-307`, `404-432`). The
  multiplier only changes on equip/upgrade — cache it in the buff when `bonus()` changes.
- [P2] **MightBuff base-stat mutation is the fragile path** (also the P1 above): switching to
  modifier hooks removes both the corruption risk and the per-equip write churn.

## Additions

- [P2] **Ring of Force unarmed path is dead** (SPD fidelity). `force_damage_roll(hero_str)`
  (`ring.gd:369-377`) — a faithful STR-scaled unarmed weapon roll — has no caller; unarmed hero
  attacks never route through it, so Force only contributes its flat armed `modify_damage` bonus.
  Wire it into the unarmed damage branch.
- [P2] **Sharpshooting / Elements are generic approximations.** Sharpshooting boosts *all*
  accuracy/damage rather than missile-only (`ring.gd:512-524`); Elements only resists `Buff`-sourced
  damage via a heal-back rather than true elemental DR (`ring.gd:323-333`). Tighten toward SPD.
- [P3] **Cursed ring sells for 0.** `value()` = `75*(level+1)` and cursed sets `level=-1`
  (`ring.gd:107,115`) → 0 gold. SPD sells cursed rings at base value; clamp `level` to ≥0 in `value()`.
- [P3] **No tests** for ring bonus curves or artifact charge/leveling curves.
- [P3] Artifact hooks (`feed_seed`/`feed_food`/`on_craft`/`on_search`/`reveal_around`) are duck-typed
  via `has_method` across UI/level — candidate for a small typed artifact-interface extraction.

## Save/load & coupling notes

- Ring serialize persists `gem_color`/`gem_name`/`ring_known` + base Item fields, but NOT the
  equipped→passive-buff relationship; the whole ring effect layer is reconstructed only by a fresh
  `on_equip`, which the load path skips (headline P1).
- Artifact serialize is thorough per-subclass (charge/exp/level + bespoke state like `invis_turns`,
  `ghost_*`, `fed_scrolls`); DriedRose even has a `resolve_post_load()` to relink its ghost. That
  pattern is the fix template the rings/other artifacts lack.
- `EnergyBuff` is the one speed/effect hook that DOES work — `wand.gd:58` reads
  `get_buff("RingOfEnergy")` during recharge. Good reference for how Wealth/loot should query.
- Heavy autoload coupling: MessageLog, EventBus, GameManager, TurnManager referenced directly
  throughout artifact.gd (acceptable for now, noted for framework extraction).

## Research notes

- SPD reference: Ring of Wealth = scaling gold + a "wealth" pity counter dropping consumables/rings;
  Ring of Force = STR-scaled unarmed weapon + small augment when armed; Cape of Thorns = blocks a
  share of incoming damage and reflects it while charged; Ring of Might = +STR and +HT (derived,
  not baked). Findings above are measured against those behaviors.
- No web search needed — all findings are grounded in cited local call-graph evidence (grep of
  `modify_speed`/`get_speed`, wealth/loot readers, `on_hero_damaged` callers, belongings load path).
