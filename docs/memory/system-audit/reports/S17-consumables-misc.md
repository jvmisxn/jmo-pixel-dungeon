# Consumables & misc items — Audit

- Files: `src/items/seeds/seed_item.gd`, `src/items/food/food.gd`, `src/items/bombs/bomb.gd`, `src/items/stones/stone.gd`, `src/items/spells/spell.gd`
- Read in full: yes (all 5)
- Verdict: **needs-hardening** — factories and per-item logic are clean and readable, but the whole category shares the `split()`→base-`Item` downgrade bug, runestones never use SPD's thrown/targeting model (all act at `hero.pos`/adjacent), and two effects reach for `Paralysis` where dedicated `SleepBuff`/`Frozen` classes already exist.

## Improvements
- [P1] **Runestones never target a cell.** `Stone.execute` → `_apply_effect` acts only on `hero.pos` or its 8 neighbours (`stone.gd:31,40`); `hero.gd:422/434` wires only `Bomb` and `SeedItem` into the throw/targeting pipeline. In SPD every runestone is *thrown at a chosen cell* — Blink teleports **to** a targeted cell (here it's a random 4-tile jump, `stone.gd:287`), Blast/Shock/Fear/Deepened-Sleep/Disarming land on a targeted cell/enemy (here only adjacent). Big fidelity + usability gap. Direction: route Stone (and Spell where applicable) through `EventBus.enter_targeting` like `SeedItem.execute` does (`seed_item.gd:60-68`), pass the picked cell into `_apply_effect`.
- [P1] **`split()` downgrades every consumable to an inert base `Item`.** None of the 5 types override `duplicate_item()` (only gold/scroll/potion/armor do — `grep`), so base `Item.split` (`item.gd:145-157`) clones a plain `Item`, dropping `plant_type`/`stone_type`/`spell_type`/`bomb_type` and food's `hunger_satisfy`/`heal_amount`/`random_effect`. Reachable via partial drop / thief-steal (same root cause logged for S12/S15). Direction: give each type a `duplicate_item()` that constructs via its own factory and copies the subtype field (mirror `Potion`/`Scroll`).
- [P2] **Frost Bomb and Deepened-Sleep Stone use `Paralysis` instead of the real buffs.** `bomb.gd:121` applies `Paralysis` for FROST and `stone.gd:342` applies a 20-turn `Paralysis` for "deep sleep", yet `src/actors/buffs/frozen.gd` and `sleep_buff.gd` both exist. Paralysis never breaks on damage, so SPD sleep (wakes when attacked) and frozen (freeze/shatter semantics) are both wrong. Direction: swap to `SleepBuff`/`Frozen`. (bomb.gd is in TRUNCATED_FILES.txt — stone side is editable.)
- [P2] **Stone of Disarming doesn't disarm.** `stone.gd:350-368` applies `Weakness` and the comment even says "Reduce the target's attack skill temporarily." SPD's disarming knocks the target's weapon to a nearby cell for several turns. Direction: implement weapon-drop-and-lock, or at minimum rename to match behavior.

## Optimizations
- [P3] **`load()` per cast in Summon Elemental.** `spell.gd:304` does `load("res://src/actors/mobs/special/summoned_elemental.gd")` on every cast. Cache via `preload`/`const` at file scope.
- [P3] **Four copies of `_consume_one`.** Near-identical implementations in `seed_item.gd:135`, `food.gd:151`, `bomb.gd:216`, `stone.gd:427`, `spell.gd:406`. Extract one protected helper on `Item` (or a `Consumable` mixin) to cut coupling and drift risk.

## Additions
- [P2] **Wild Energy grants a non-SPD free upgrade.** `spell.gd:104-111` gives a 30% chance to `upgrade()` a random inventory item — not in SPD (Wild Energy recharges wands/staff and emits damaging electric sparks). It's an exploitable freebie. Direction: drop the random upgrade; add the spark AoE for parity.
- [P3] **Mystery-meat effect table is a flat 4-way roll.** `food.gd:81` `randi_range(0,3)` over heal/poison/burn/paralyze. SPD's MysteryMeat weights effects differently (and can also do nothing). Low value; note for later balance parity.
- [P3] **Regrowth Bomb only paints HIGH_GRASS.** `bomb.gd:175-184` sets terrain but spawns no `Regrowth`/plant actors like SPD's regrowth blob. Framework hook for the plant/blob system (couples S19/S20).

## Save/load & coupling notes
- Serialization is sound per-type: each writes its discriminator (`plant_type`, `bomb_type`, `stone_type`, `spell_type`, food fields) and re-`_configure`s on load (`seed_item.gd:143-152`, etc.). The only persistence hole is the `split()`/`duplicate_item()` downgrade above, which corrupts a stack *before* it is ever serialized.
- Autoload coupling is heavy but guarded: `EventBus`, `MessageLog`, `GameManager`, `NetworkManager`, `Generator` are all null-checked. Stone/Spell carry full host→peer `send_ui_event_to_peer` fan-out for windowed choices (enchant/augment/recycle/curse-infusion) — solid for multiplayer, but it means these files know a lot about the netcode.

## Research notes
- SPD runestones (`Runestone`/`StoneOfBlink` etc.) extend a thrown `Item` and resolve on a *targeted cell*; Blink is targeted teleport, Blast is a thrown 1-tile explosion. Confirms the "no targeting" P1.
- SPD `MysteryMeat` and `FrozenCarpaccio` both satisfy `Hunger.HUNGRY/2` (150) — matches the ported values (`food.gd:216,240`). Good parity there.
- Verified against repo: `frozen.gd`, `sleep_buff.gd`, `charm.gd` exist as buffs; `duplicate_item` overridden only in gold/scroll/potion/armor (`grep`); throw pipeline handles only `Bomb`/`SeedItem` (`hero.gd:422,434`).
