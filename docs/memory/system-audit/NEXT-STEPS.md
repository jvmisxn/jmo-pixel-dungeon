# NEXT STEPS — Post-Audit Remediation Plan

Synthesized 2026-07-11 from the 37-system audit (`reports/S01–S37`), `backlog.md`
(~140 tagged findings), and the repo's own strategy docs (active-context,
framework-extraction-roadmap, multiplayer-roadmap, persistence-notes).

**Standing constraints (apply to every workstream):**
- No Godot engine on this machine → verification is `gdparse`/`gdlint` + reasoning.
  Items marked **[ENGINE]** are not trustworthy until played in-engine (or in CI, see WS1).
- Files in `TRUNCATED_FILES.txt` (hero.gd, level.gd, char.gd, game_manager.gd,
  save_manager.gd, wand.gd, game_scene.gd, …) break the repo if truncated —
  marked **[TRUNC]**; hand-edit carefully, re-verify with gdparse, small diffs only.
- `SAVE_VERSION` currently only rejects *newer* saves. Any fix that alters the save
  contract is marked **[SAVE]** and must land *after* the WS2 migration scaffold
  (`_migrate(save, from_version)` + version bump per change).
- PR #1 (`audit/autofix`) holds mechanically-safe cleanups — merge before starting.

---

## 1. Executive read

The port is broad, playable, and mostly *faithful in its per-system logic* — the
audit found very few crashes and no rotten architecture. The real through-line is
that a large share of what was built is **not wired into the running game**: whole
subsystems have no driver (blob gas sim, wand recharge, boss HP bar, bags, sprite
buff feedback, most of the UI component kit), canonical APIs exist but the live
paths bypass them (dropping the MAX_DEPTH cap, gold signals, door rules), and the
save contract silently loses state on every load (ring/artifact passives, combat
state, scheduler cooldowns — plus Ring of Might actively *corrupts* saved stats).
The dominant failure mode is silent inertness and silent data loss, not breakage —
which is exactly why it survived play-testing this long. One finding is P0 (wands
never recharge), roughly 65 are P1. The bottleneck on everything is verification:
with no local engine, CI + a headless test harness is the first keystone, not a
nice-to-have.

---

## 2. Cross-cutting themes (root causes)

**T1 — Built-but-never-driven.** One end of a feature exists; the driver was never
plugged in. Blob sim (`Blob.act()` never called → *why* potions/plants/traps all
fake gases with one-shot buffs), wand recharge (no per-turn Charger → P0),
boss HP bar (3 signals subscribed, zero emitters), sprite VisualState +
BuffIcon/HealthBar/Toast/UIUtils (0 callers), bags/iron keys/skeleton keys,
thrown-potion shatter, stone targeting, Combo/imbue procs, class passives,
door/`connected` system in levelgen, `SceneManager` never setting
`tree.current_scene` (kills per-mob-action refresh). ~40 findings reduce to
"wire the driver."

**T2 — Canonical API bypassed by open-coded copies.** The safe chokepoint exists
and is dead; live code hand-copies it minus the rails. `descend()/ascend()`
(MAX_DEPTH cap lost — S24+S26, one fix closes both), `spend_gold()` (stale gold
HUD), door-open triplicated, ~230 lines of dead-but-drifting input/visibility
code in game_scene, SaveManager hand-copying 11 GameManager fields (how
`quest_flags` got missed), 3× `_cell_to_world`, hardcoded badge/transmute ID
lists, offline windows mutating game state instead of `request_hero_action`.

**T3 — Save/load contract holes.** Durability: no autosave, non-atomic write, no
migration path (S01). Coverage: `Char` has no combat-state serializer (S03),
equipped rings/artifacts go inert on load + Ring of Might stat corruption (S16),
SpiritBow deserialize is `pass` (S13), TurnManager cooldowns wiped (S04),
charm/terror `source_id` dropped (S06), bag contents dropped (S18), `quest_flags`
not saved (S26), MessageLog bleeds across runs (S30), `_generated_artifacts` and
NPC reward-RNG churn on load (S12/S21).

**T4 — SPD-fidelity gaps in the differentiation/effect layer.** Same-tier weapons
identical (S13), uniform instead of bell-curve damage rolls (S03/S14), surprise
attacks only for invisible attackers (S03), Doom invented / Fury double-counted /
speed hooks dead (S06), five broken wand subclasses (S14), traps inert or
unpooled (S10, Halls trap tier S09), wrong buff types (Paralysis standing in for
Frozen/Sleep — S15/S17/S19), chasms instant-death (S11), swarm HP duplication
(S05), no mob respawn + under-spawn (S07), armor never spawns glyphs (S13),
Blacksmith quest uncompletable (S21).

**T5 — No verification substrate.** ~20 systems flagged "no tests" over pure,
headless-testable logic (geometry, codecs, item round-trips, scheduler math,
bus contract). A signal emitter+consumer contract test alone would have caught
the four dead boss/cancel signals mechanically. Blocked locally by no engine —
solved by CI (WS1).

---

## 3. Sequenced workstreams

Ordered by dependency and unlock-value, not system number. Effort: S (<½ day),
M (1–3 days), L (multi-day).

### WS0 — Merge PR #1 + backlog hygiene — **S, no risk**
- Merge `audit/autofix` (PR #1, mechanically-safe, already gdparse-verified).
- **File the 7 S36 (windows) findings into backlog.md — they were never filed**,
  incl. a P1 runtime crash (drop equipped ring → `belongings.ring` doesn't exist,
  `wnd_item.gd:284`) and offline-path state mutation in the view layer.
- Closes: [audit:S36] filing gap. Touches: docs only.

### WS1 — CI + headless test harness (verification keystone) — **M, low risk**
- GitHub Actions job: install Godot 4.5 headless → `gdparse` every file (truncation
  tripwire), gdlint, then a minimal test runner (GUT or bespoke `SceneTree` script).
- Seed tests for pure logic: Ballistica/ShadowCaster/Pathfinder geometry (S22),
  online codecs round-trip (S31), item serialize→create→deserialize (S12),
  scheduler cooldown math (S04), **EventBus emitter+consumer contract test** (S27),
  badge count invariant (S29).
- Why first: with no local engine, this is the only scalable trust mechanism for
  everything below; it also permanently guards against the repo's truncation
  failure mode.
- Closes/enables: the ~20 "no tests" findings [audit:S02..S37]; makes [ENGINE]
  items partially checkable in CI. Touches: new files only. No save impact.

### WS2 — Save durability + canonical lifecycle APIs — **M, medium risk** [TRUNC][SAVE]
- Atomic write (`.tmp` → rename + `.bak` rotation) and autosave on floor
  transition + `NOTIFICATION_WM_CLOSE_REQUEST` [audit:S01 both P1s].
- `_migrate(save, from_version)` scaffold + per-change SAVE_VERSION bumps
  [audit:S01] — **prerequisite for every [SAVE] item below**.
- Delete the ~200-line dead, wrong-contract serialization block in
  save_manager.gd:309-537 [audit:S01].
- Route `floor_transition_coordinator` through `GameManager.descend()/ascend()` —
  restores the MAX_DEPTH cap, closes the same bug in two systems
  [audit:S24 P1×2][audit:S26 P1].
- Route all gold spends through `spend_gold()` (emit `gold_collected(-amt)`)
  [audit:S26]; add `GameManager.serialize_run_state()/apply_run_state()` chokepoint
  + persist `quest_flags` [audit:S26].
- `MessageLog.clear()` + turn reset on new-game/load [audit:S30 P1].
- Touches: save_manager.gd, game_manager.gd, message_log.gd (all [TRUNC]),
  floor_transition_coordinator.gd (safe). Playtest: autosave-on-close is [ENGINE];
  the rest is statically verifiable + CI-testable.

### WS3 — Buff/modifier dispatch unification — **M, medium risk** [TRUNC]
- `get_speed()` iterates `modify_speed()` hooks → un-deadens Sleep/Dread/
  MonkFlurry/FreerunnerMomentum **and** Rings of Furor + Haste in one change
  [audit:S06 P1][audit:S16 P1].
- Single damage-mod path (kills Fury 2.25× double-count) [audit:S06 P1];
  Doom → damage-taken amplifier [audit:S06 P1]; add a damage-taken hook in
  `take_damage` (this is also the plug Cape of Thorns needs [audit:S16 P1]).
- Ring of Might via modifier hooks, never base-stat writes — stops save-state
  corruption [audit:S16 P1] [SAVE: migration should re-derive/clamp inflated stats].
- Interval-gated Barkskin/ArcaneArmor decay, unified shield API (Barrier),
  Frozen potion-loop dedent, buff_id index for O(1) lookups
  [audit:S06 P1/P2s][audit:S03 P2].
- Touches: char.gd [TRUNC], ring.gd, individual buffs (safe). Combat feel is
  [ENGINE], logic CI-testable.

### WS4 — Save-contract completeness — **L, medium risk** [TRUNC][SAVE]
(after WS2's migration scaffold)
- `Char.serialize_char()/deserialize_char()` for the combat block; subclasses
  super-call [audit:S03 P1].
- On load, re-run the real equip path / `_apply_passive` for rings + artifacts and
  persist the ring↔buff link — un-deadens every equipped ring/artifact after
  reload [audit:S16 P1].
- TurnManager `{actor_id: cooldown}` persistence + live speed re-query
  [audit:S04 P2×2]; charm/terror deserialize [audit:S06]; item `bones`/
  `kept_though_lost_invent` [audit:S12]; `Bag.deserialize` items [audit:S18];
  `_generated_artifacts` persistence [audit:S12]; NPC lazy reward generation
  (stop RNG churn on load) [audit:S21]; ItemCatalog typed-dict coercion
  [audit:S29].
- Touches: char.gd, actor.gd, belongings.gd, hero.gd, save_manager.gd,
  turn_manager.gd — the [TRUNC] heartland; smallest possible diffs, CI round-trip
  tests per contract. Playtest: load-a-real-run is [ENGINE].

### WS5 — Blob sim revival (biggest content unlock) — **L, high risk** [TRUNC][ENGINE]
- Drive `Blob.act()` once per hero round (`level.tick_blobs()` mirroring
  `tick_pending_bombs`) [audit:S20 P1]; fix `_spread` mutate-while-iterating
  [audit:S20 P2]; real blob serialize/factory contract [audit:S20 P2] [SAVE];
  `add_blob` density passthrough.
- Then re-point the fakes at real blobs: gas potions (ToxicGas/Paralytic/
  LiquidFlame/Frost) [audit:S15 P1], plants (Firebloom/Sorrowmoss/Stormvine/
  Icecap) [audit:S19 P1], wand corrosion [audit:S14], regrowth bomb [audit:S17];
  add missing blob classes (Freezing, StormCloud, SmokeScreen — un-deadens the
  LOS smoke branch) [audit:S20].
- Unlocks ~10 findings across four systems in one dependency chain.
  Touches: level.gd [TRUNC]. Spread/decay balance is firmly [ENGINE];
  lifecycle logic is CI-testable.

### WS6 — Items that don't work: split/throw/keys/bags — **M, medium risk** [TRUNC]
- Base `duplicate_item()` reconstructs via `Generator.create_item(item_id)` —
  one fix closes the split-downgrade family across missiles/seeds/bombs/stones/
  food/spells/potions/scrolls [audit:S12 P1][audit:S15 P1][audit:S17 P1].
- Thrown-potion `shatter()` branch in `_do_throw_item` [audit:S15 P1] (pairs
  with WS5 so shattering seeds real gas).
- Stones through the targeting pipeline [audit:S17 P1]; wrong-buff swaps →
  Frozen/SleepBuff [audit:S15/S17/S19].
- LOCKED_DOOR → iron keys (un-deadens iron *and* gives golden keys their real
  job); decide skeleton-key gate [audit:S11 P1][audit:S18 P1×2]; bag auto-collect
  + `bags` array in belongings [audit:S18 P1]; holster missile support.
- Touches: item.gd, hero.gd [TRUNC], door.gd [TRUNC], scroll.gd [TRUNC],
  bomb.gd [TRUNC], belongings.gd [TRUNC]. Mostly CI-testable; throw-UX is [ENGINE].

### WS7 — Wands: recharge (the P0) + subclass fixes — **M, medium risk** [TRUNC][ENGINE]
- Per-hero-turn Charger buff on equip → `recharge(1, hero)` × Recharging/
  battlemage multipliers [audit:S14 **P0**].
- Frost `was_chilled` gate; Corruption → `CorruptionBuff`; Disintegration through
  `take_damage`; Warding spawns a real sentry; id-uses refill on level/descend
  [audit:S14 P1×5].
- Shared `Balance.normal_int_range()` helper; adopt in wands + `Char.damage_roll`
  (closes the S03 bell-curve P1 too) [audit:S14 P2][audit:S03 P1].
- Touches: wand.gd [TRUNC] — the riskiest single file; small sequenced diffs.
  Wand balance is [ENGINE].

### WS8 — World interactions: traps, chasms, spawning — **M, medium risk** [TRUNC][ENGINE]
- Chasm = real fall (Levitation check → descend + scaled damage + "fell" flag to
  the transition coordinator), retire the inline instant-death [audit:S11 P1,
  reachable via S09 knockback]; pitfall trap rides the same path [audit:S10].
- Inert traps: paralytic/fire apply their buffs; disarming reads
  `belongings.get_equipped_weapon()` (arg-swap already a quick win); cursing path;
  wire the 7 orphaned trap classes into region pools [audit:S10 P1×3, P2×3].
- Mob population: fix under-spawn loop + fallback + 25% second-mob; add periodic
  respawner; mimic keeps its item [audit:S07 P1×2, P2].
- Door-open logic unified in one helper [audit:S11 P2].
- Touches: hero.gd, level.gd, regular_level.gd, several trap files [TRUNC subset].
  Fall/respawn pacing is [ENGINE].

### WS9 — Boss-fight completeness — **M, low-medium risk** [TRUNC][ENGINE]
- Emit `boss_fight_started/damaged/defeated` → un-deadens the fully-built HUD bar
  [audit:S27 P1][audit:S35 P1][audit:S09]; viewport-relative bar centering.
- Halls trap-pool override [audit:S09 P1]; bidirectional stair seal (retire dead
  `floor_sealed`); arena chasm-ring knockback fix (pairs with WS8 chasm);
  traversability assert in boss `_build()`; boss-finale music trigger
  [audit:S09 P2s][audit:S30 P2].
- Extract shared `BossArenaLevel` scaffold (one home for the validation fix)
  [audit:S09 P2 — first real framework-extraction move, earned not speculative].
- Boss fights are the definition of [ENGINE].

### WS10 — Scene flow + render pipeline correctness/perf — **M, medium risk** [TRUNC][ENGINE]
- `SceneManager` sets `tree.current_scene` (or TurnManager reads
  `SceneManager.current_scene`) → un-deadens per-mob-action refresh
  [audit:S28 P1]; MainScene leak + re-entrancy guard [audit:S28 P2s].
- Coalesce FOV/visibility rebuild to once per turn (currently O(mobs) full
  repaints) [audit:S25 P1]; sprite-vs-visibility ordering; heap-top icon refresh
  [audit:S25 P2s].
- Wire `Char.update_sprite_state()` → VisualState (buff feedback on sprites)
  [audit:S32 P1]; adopt BuffIcon (+ buffs.png atlas) over ColorRects
  [audit:S37 P1][audit:S35 P2]; mob die/fall animations [audit:S32 P2];
  delete the ~230 lines of dead drifted input/visibility bodies in game_scene
  [audit:S23 P1][audit:S25 P2]; targeting swallows non-ESC input [audit:S23 P1].
- Touches: game_scene.gd [TRUNC — the scariest hand-edit in the plan, do the
  dead-code deletion as its own reviewed diff], scene_manager.gd, char_sprite.gd
  [TRUNC]. Visual behavior is [ENGINE].

### WS11 — Weapon/armor differentiation + hero identity — **M, low risk** [TRUNC][ENGINE]
- Per-weapon `delay_factor`/damage overrides within tiers [audit:S13 P1];
  armor glyphs on random loot [audit:S13 P1]; curse-enchant dispatch +
  generation; Flow/Entanglement real buffs; `is_curse` on glyphs [audit:S13 P2s].
- Hero identity stubs: Mage's real starting staff/wand, Warrior/Rogue passives
  (implement or stop advertising), surprise-attack flag threading
  [audit:S02 P1×2][audit:S03 P1]; Gladiator Combo wiring [audit:S06 P1];
  mark inert talents in the picker [audit:S02].
- Balance is [ENGINE]; math is CI-testable.

### WS12 — UI action-path + quest/content unification — **M, low risk** [TRUNC]
- Windows' offline branches routed through `request_hero_action` (kills the
  view-layer state mutation / online-offline divergence) [S36 P1].
- `Ring.all_ids()`/`Wand.all_ids()` + consume in transmute; badge grid driven
  from catalog [S36 P1/P3][audit:S29].
- Blacksmith ore source (makes the quest completable) [audit:S21 P1]; quest
  depth/spawn single-source; a `quest_updated` consumer (journal/toast) so 11
  emit sites stop being dead broadcast [audit:S27 P2]; Toast autoload adoption
  [audit:S37 P2].

### WS13 — Level-gen door system — **L, high risk** [TRUNC][ENGINE]
- Fix `connected`/door layer: wall-sharing adjacency or tunnel-mouth doors —
  restores DOOR/LOCKED_DOOR painting, vault/armory key gates, garden/shop doors
  [audit:S08 P1]; `pair_key` int64 overflow → keyed tunnels [audit:S08 P2];
  connection-room placement [audit:S08 P2].
- Sequenced late deliberately: highest regen-behavior risk, needs seeded-gen CI
  tests (door-count/reachability assertions) + in-engine floor inspection, and it
  interacts with WS6's key economy (land keys first so locked doors are fair).

---

## 4. Immediate quick wins (before/alongside WS1)

All small, self-contained, high-value. Non-[TRUNC] unless noted.

1. **Merge PR #1** (audit/autofix).
2. **File S36 findings into backlog** (currently report-only).
3. `fetid_rat.gd:26-28` — fix the two arg-count crashes (`seed`/`add_blob`) [audit:S20 P1].
4. `disarming_trap.gd:44-47` — swap `drop_item(weapon, pos)` → `(pos, weapon)`; permanent item loss [audit:S10 P1].
5. `swarm.gd:43-45` — split HP instead of duplicating [audit:S05 P1].
6. `spirit_bow.gd:143` — `deserialize` calls `super` instead of `pass`; stops bow data loss [audit:S13 P1].
7. `frozen.gd:36-45` — dedent freeze block out of the item loop [audit:S06 P1].
8. `charm.gd`/`terror.gd` — add matching `deserialize` for `source_id` [audit:S06 P2].
9. `minimap.gd:244-245` — read `level.visible` (property `visible_cells` doesn't exist) [audit:S35 P2].
10. `badges.gd` — add the 3 missing IDs to `_ALL_BADGE_IDS` (26/23 bug) [audit:S29 P1].
11. `network_manager.gd:317` — pass `local_profile_icon_id` in `set_local_ready` [audit:S31 P2].
12. `network_manager.gd:671` — clients consume host run-config verbatim (whole-run desync risk) [audit:S31 P1].
13. `item_catalog.gd:110` — coerce untyped dict on load [audit:S29 P2].
14. `wnd_item.gd:284` — mirror ring_left/ring_right in `_action_drop` (runtime crash) [S36 P1] **[TRUNC — careful edit + gdparse]**.
15. `ghost.gd:48-50` — drop the double `mob_defeated` subscription [audit:S21 P2].

Each verified with gdparse + gdlint; none alter the save contract (item 6 only
*reads* data already being written).

---

## 5. Explicitly deferred

Per the repo's own strategy (harden the port first — active-context.md, framework
roadmap Phase A):

- **Framework extraction Phases B–E** — namespaced `src/framework/` modules,
  content registries, spin-off game, repo split. Only extraction earned by fixes
  lands now (e.g. WS9's `BossArenaLevel`, shared `Balance.normal_int_range`).
- **Multiplayer hardening beyond correctness fixes** — delta/dirty snapshot sync
  [audit:S31 P1-opt], NetworkManager god-object split, mid-run online resume,
  `_detailed`-signal consolidation [audit:S27 P3]. The two cheap S31 correctness
  fixes are pulled forward into quick wins; the rest waits for the command/event
  pipeline work the MP roadmap already sequences.
- **Blocked on in-engine playtesting** (get Godot locally or lean on WS1 CI +
  recorded runs): final balance for WS5 blob spread, WS7 wand feel, WS9 boss
  encounters, WS13 level-gen shape; DARK-feeling view distance [audit:S07 P3];
  Halls view-distance field [audit:S09 P2].
- **Polish / parity extras** — SPD splash/blood/typed-bolt effects [audit:S34],
  alternate builders (Line/FigureEight) [audit:S08 P3], full Blacksmith
  mining/favor quest [audit:S21 P2], auto-aim/last-target QoL [audit:S23 P2],
  procedural SFX synthesis [audit:S30 P2], curse armor glyphs [audit:S13 P3],
  perf micro-items (O(n) scans, pow() caches, per-frame `_process` trims) unless
  profiling says otherwise.
- **BattlemagePower rename** [audit:S02 P3] and similar serialized-id renames —
  park until several [SAVE] changes batch into one migration.

---

## Suggested execution order (TL;DR)

Quick wins → WS0 → WS1 (CI) → WS2 (durability+APIs) → WS3 (buff hooks) →
WS4 (save contract) → WS5 (blobs) → WS6 (items) → WS7 (wands) → WS8 (world) →
WS9 (bosses) → WS10 (scene/render) → WS11 (weapons/identity) → WS12 (UI/quests) →
WS13 (doors). WS5–WS9 parallelize reasonably after WS4; WS10 and WS13 want the
most in-engine time, so schedule them around when Godot/CI playtesting exists.
