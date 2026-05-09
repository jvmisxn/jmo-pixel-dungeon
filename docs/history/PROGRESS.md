# Shattered Pixel Dungeon — Godot Build Progress

## Completed
- **Core Framework** (2026-05-02): autoloads (constants.gd, game_manager.gd, turn_manager.gd, event_bus.gd, message_log.gd), mechanics (shadow_caster.gd, pathfinder.gd, ballistica.gd), project.godot configured, main_scene.tscn placeholder
- **Phase 1: Dungeon Generation** (2026-05-02): Complete procedural level generation system — 43 files under src/levels/
- **Phase 2: Actors & Combat** (2026-05-02): Complete actor/combat system — 62 files under src/actors/
- **Phase 3: Items & Inventory** (2026-05-02): Complete item hierarchy — 27 files, ~10,000 lines under src/items/
- **Phase 4: Rendering & Visuals** (2026-05-02): Complete rendering system — 14 files under src/tiles/, src/sprites/, src/effects/, src/scenes/
- **Phase 5: UI & Menus** (2026-05-02): Complete UI system — 24 files under src/ui/, src/scenes/
- **Phase 6: Integration & Polish** (2026-05-02): Plants system, NPC quests, audio framework, save/load, balance reference, web export config, REMAINING_WORK.md

## Quality Pass (2026-05-02)
- **Special Mobs** — 4 new mob types under src/actors/mobs/special/:
  - piranha.gd — Water-restricted glass cannon, scales with depth, always drops food, tracks piranhas_slain stat
  - mimic.gd — Disguised as item heap, reveals on interaction/damage, fast+aggressive, stores loot
  - animated_statue.gd — Passive mini-boss near statue terrain, wields enchanted weapon (drops on death), leash to spawn
  - golden_statue.gd — Rare variant of animated statue, extra tanky (25% damage reduction), drops highly upgraded weapon
- **MobFactory** — Added create_mob entries for all 4 special types + factory helpers: create_piranhas(), create_mimic(), create_animated_statue(), create_golden_statue()
- **MobSprite** — Added visual definitions for piranha (blue/small), mimic (brown/large), animated_statue (gray/large), golden_statue (gold/large)
- **RegularLevel** — Added spawn_piranhas(), try_spawn_mimic(), try_spawn_animated_statue(), try_spawn_golden_statue() with depth-scaling and probability control
- **Subclass Abilities** — Full implementation for all 10 subclasses:
  - subclass_abilities.gd — Central registry with SubclassInfo data and apply_subclass() method
  - hero_class_data.gd — Added get_subclass_name() and get_subclass_description()
  - 10 subclass buff files under src/actors/buffs/subclass/:
    - berserker_rage.gd — Damage scales with missing HP, rage buildup prevents one death per fight
    - gladiator_combo.gd — Hit counter with combo finisher (1.5x at 3 hits, up to 3x at 10)
    - battlemage_power.gd — 33% wand recharge, staff on-hit triggers imbued wand effect
    - soul_mark_passive.gd + soul_mark.gd — Wand hits mark enemies, killing marked enemies heals+satiates
    - assassin_preparation.gd — Builds prep while hidden (up to 3x damage), resets on strike
    - freerunner_momentum.gd — Movement builds momentum (+50% evasion/speed at max), resets on attack
    - sniper_mark.gd — +50% ranged accuracy, snapshot (free ranged attack) every 3 turns
    - warden_barkskin.gd — Walking on grass grants temporary armor, doubled plant/seed effects
    - champion_dual_wield.gd — Equip secondary weapon, alternating attacks, both contribute to defense
    - monk_flurry.gd — Unarmed speed scales with consecutive hits (up to 3x), Focus after dodge
- **Integration Fixes**:
  - char.gd: on_move() now notifies all buffs; attack() notifies buffs via on_damage_dealt; dodge notifies target buffs; die() checks _try_prevent_death() before killing
  - hero.gd: Added _try_prevent_death() for Berserker rage and blessed Ankh; attack resolves target from target_pos; auto-reveals disguised mimics
  - mob.gd: _drop_loot() now creates items via Generator; _on_death() checks Soul Mark; on_move() delegates to super
  - event_bus.gd: Added mob_died and mob_revealed signals
  - game_scene.gd: Attack actions now pass both target ref and target_pos; mimic disguise renders as item sprite until reveal; _on_mob_revealed swaps sprite; null-safe mob sprite iteration

## Quality Pass 2 (2026-05-02)
- **Enchantment/Glyph Visual Effects** — All 9 weapon enchantments and 12 armor glyphs now trigger visual feedback during combat:
  - event_bus.gd: Added enchantment_proc and glyph_proc signals
  - weapon_enchantment.gd: Added _emit_proc() helper; blazing→fire burst+ring, chilling→ice particles+ring, shocking→lightning arc, lucky→green status text+particles, grim→dark screen flash+purple ring, vampiric→red projectile from defender to attacker, elastic→green knockback particles
  - armor_glyph.gd: Added _emit_glyph_proc() helper; all 12 glyphs emit on proc (obfuscation→shimmer ring, repulsion→knockback projectile, thorns→red projectile, potential→lightning, brimstone→fire particles, entanglement→root particles+status, etc.)
  - game_scene.gd: Connected both signals with full visual dispatch handlers
- **Badge/Achievement System** — 26 badges across 5 categories with persistent storage:
  - badges.gd: New BadgesManager autoload (registered in project.godot)
  - Progress badges (first_victory, all_classes_won, boss_slain_1-5, depth_10, depth_20)
  - Combat badges (enemies_slain_10/50/100/250, piranhas_slain_5)
  - Collection badges (all_potions_identified, all_scrolls_identified, gold_collected_500/2500/5000, items_collected_50)
  - Skill badges (no_armor_win, no_food_win, champion_win, strength_15)
  - Death badges (first_death, death_by_goo)
  - Per-run tracking for armor/food/piranhas/identifications, persistent class wins
  - Saves to user://badges.dat, emits EventBus.badge_unlocked, logs to MessageLog
- **NPC Reward Selection UIs** — 3 new window types:
  - wnd_quest_reward.gd: Reusable reward picker (Ghost weapon/armor choice, Wandmaker wand selection, Imp ring selection) with ItemSlot display, info panel, and Choose button
  - wnd_reforge.gd: Blacksmith reforge with Keep/Consume target slots, filterable inventory grid (weapons+armor only), upgrade transfer preview, reforge execution
  - wnd_transmute.gd: Scroll of Transmutation item picker with category filter tabs, transmutation logic for 7 item categories preserving upgrade levels
- **Scroll of Transmutation Fix** — scroll.gd modified to open WndTransmute UI instead of auto-transmuting; fallback to old behavior if GameScene unavailable

## Integration Fix Pass (2026-05-02)
Critical bugs found and fixed that would have prevented the game from being playable:

- **Hero.level never set** — The hero's `level` reference (from Actor base class) was never assigned, breaking movement validation, terrain interaction, door opening, visibility checks, attack target resolution, and all terrain effects. Fixed in loading_scene.gd to set `hero.level = level` (and for all heroes in the multiplayer array) right after level generation.

- **Empty dungeons — no mobs or items spawned** — `RegularLevel._build()` generated rooms, corridors, and traps, but never called `mob_count()`/`mob_spawn_positions()` or `item_count()`/`item_spawn_positions()`. Added Steps 7-9 to `_build()`:
  - Step 7: Spawn mobs via `MobFactory.create_random_mob(depth)` at positions from `mob_spawn_positions()`
  - Step 8: Spawn floor loot via `Generator.random_item(depth)` at positions from `item_spawn_positions()`
  - Step 9: Special spawns — piranhas, mimics, animated statues, golden statues

- **Boss levels had no bosses** — All 5 boss levels (sewer/prison/caves/city/halls) generated arenas but never spawned their boss mob. Added `MobFactory.create_boss(depth)` calls to each boss level's `_build()`: Goo at depth 5, Tengu at 10, DM-300 at 15, Dwarf King at 20, Yog-Dzewa at 25.

- **Last level had no Amulet of Yendor** — The final level (depth 26) created the pedestal chamber but never placed the victory item. Added `Generator.create_item("amulet_of_yendor")` placement on the pedestal.

- **Boss exit unlock broken** — `unlock_exit()` only checked cells adjacent to `exit_pos`, but boss levels place their locked door 2-3 cells away from the exit. Fixed to scan the entire level for `LOCKED_DOOR` terrain and open all of them.

- **No trap generation in base RegularLevel** — `_create_random_trap()` returned null. Region subclasses override it properly, but the base fallback was a no-op. Added fallback trap generation (worn dart, poison, fire, alarm, teleport).

- **Doors not auto-opening** — Hero could walk onto a closed DOOR cell (marked passable) but the door terrain was never changed to OPEN_DOOR. Added auto-open logic in `hero._do_move()` to open doors before stepping through and emit the `door_opened` signal.

## Critical Bug Fix Pass (2026-05-02)
Game-breaking bugs found and fixed through deep code audit:

- **Hero buffs never processed** — TurnManager detects heroes and pauses without calling act(), so process_buffs() was never invoked. Hunger never drained, Regeneration never healed, Poison/Burning never ticked on the hero. Fixed: hero.execute_action() now calls process_buffs() before executing the action.

- **TurnManager speed cache stale** — Speed was cached at actor registration and never refreshed. Haste/Cripple/slow buffs had no effect on turn frequency. Fixed: both hero.execute_action() and mob.act() now call TurnManager.refresh_speed(self) after processing buffs.

- **Wandmaker quest crash — swapped drop_item arguments** — quest_handler.gd called level_ref.drop_item(seed_item, item_pos) but Level.drop_item takes (pos, item). Would crash whenever the Wandmaker quest spawned (depths 7-9). Fixed argument order.

- **Hero attack target resolution used cleared dictionary** — hero._do_attack() tried to read target_pos from _pending_action as a fallback, but execute_action() already cleared it to {}. Target resolution from position always failed. Fixed: target_pos is now passed as a parameter directly from the action dict.

- **Double window opens from duplicate toolbar connections** — Both HUD and GameScene connected to the same toolbar signals (inventory_pressed, settings_pressed), causing two windows to open simultaneously. Fixed: GameScene now only connects wait/search actions; HUD handles inventory/map/settings.

- **Hero ascend/descend double-trigger risk** — hero._do_ascend() and _do_descend() called GameManager.ascend()/descend() directly, duplicating the logic in GameScene._handle_ascend()/descend(). Fixed: hero methods are now no-ops (GameScene handles all level transitions).

- **Hero HP changes not updating HUD** — Taking damage and healing didn't emit hero_stats_changed, so the HUD health bar was stale until the next level change or XP gain. Fixed: Hero now overrides take_damage() and heal() to emit hero_stats_changed, and records damage_taken stat.

## Deep Audit Pass (2026-05-02)
Critical gameplay-breaking bugs found through systematic code audit of turn system, input handling, and level persistence:

- **CRITICAL: Double energy spend per hero action** — `game_scene._submit_hero_action()` called both `hero.submit_action(action)` (which internally calls `spend_turn()` + `TurnManager.hero_action_complete()`) AND then called `TurnManager.spend_energy()` + `TurnManager.hero_action_complete()` again. Effect: hero spent 2x energy per action (half speed), AI mobs got two full rounds of turns per hero action. Fixed: removed duplicate spend_energy and hero_action_complete calls from game_scene.gd.

- **Stairs keys swapped** — `<` triggered descend and `>` triggered ascend, opposite of roguelike convention (NetHack, SPD, etc.). Fixed: `<` = ascend, `>` = descend.

- **Keyboard input not consumed** — GameScene handled movement/wait keys but never called `set_input_as_handled()`, so Toolbar also processed the same keys (Space → duplicate wait signal, though guarded). Fixed: `_handle_key_input()` now returns bool, and input is consumed when handled.

- **Dead mobs never removed from TurnManager** — Mobs were registered via `TurnManager.register_actor()` directly, bypassing `Actor.activate()`. Their `active` flag stayed `false`, so `deactivate()` (called on death) short-circuited, leaving dead mobs in the turn queue forever. Dead mobs would continue taking AI turns. Fixed: loading_scene now uses `mob.activate()` instead of direct registration; mob.act() now checks `is_alive` as a safety net.

- **Level cache lost all entities on backtracking** — `Level.serialize()` only saved terrain, visited, and mapped arrays. When ascending and returning to a floor, all items, mobs, and traps were lost. Fixed: Level.serialize() now saves heaps (with full item serialization), mobs (with mob_id and state), and traps (with type and active state). Level.deserialize() recreates entities via Generator.create_item() and MobFactory.create_mob(), restoring their saved state.

## Structural Integrity Audit (2026-05-02)
Comprehensive code audit of all cross-file references, method calls, and integration points:

- **Victory condition broken — `has_item_by_id()` missing** — `game_scene._handle_ascend()` checked for the Amulet of Yendor via `belongings.has_item_by_id("amulet_of_yendor")`, but Belongings only had `find_item_by_id()`. The `has_method()` guard prevented a crash but silently made victory impossible. Fixed: added `has_item_by_id()` to Belongings as a wrapper around `find_item_by_id()`. Also enhanced `find_item_by_id()` to search equipped items (weapon/armor/artifact/rings/misc) in addition to backpack.

- **Death cause always "the dungeon" — `last_damage_source` never tracked** — `game_scene._transition_to_death()` tried to read `hero.last_damage_source` for the death screen, but this property was never defined on Char. The `.get()` guard prevented a crash but the cause was always the default "the dungeon". Fixed: added `var last_damage_source: Variant` to Char, updated `take_damage()` to record the source when damage > 0, and improved death scene source formatting to use `mob_name` when available.

- **Testing path had stale actor registration bug** — `main_scene._start_new_game()` (debug/testing path) used `TurnManager.register_actor()` directly instead of `mob.activate()`, which was the same bug already fixed in loading_scene.gd. Dead mobs wouldn't be removed from the turn queue. Fixed: changed to use `activate()` with `active = false` reset, matching the loading_scene pattern.

- **Verified correct**: All 8 autoload files exist and are registered in project.godot. All class_name declarations are unique and properly typed. All static utility classes (QuestHandler, LevelFactory, MobFactory, Generator, HeroClassData) have correctly static methods. All sprite API methods (place_at, setup_for_class, setup_for_mob, set_visible_state, setup_from_item, setup_manual, play_pickup, play_drop) exist and are reachable via inheritance. All Level API methods called by GameScene exist. All signal names match between emitters and listeners. All preload/load paths reference existing files. Turn system, buff processing, and combat chain are correctly integrated.

## Save/Load & Serialization Fix Pass (2026-05-02)
Critical save/load bugs that would cause total data loss, crashes, or corrupted state:

- **CRITICAL: Equipped items lost on save/load** — `Belongings.serialize()` only saved backpack items, completely ignoring all 6 equipment slots (weapon, armor, artifact, misc, ring_left, ring_right). All equipped gear was silently lost. Also had NO `deserialize()` method at all, so even backpack items could never be restored. Fixed: `serialize()` now saves all equipment slots; added full `deserialize()` that restores backpack via `Generator.create_item()` + `item.deserialize()` and equipment via direct slot assignment (no equip side effects). Also fixed `Hero.deserialize()` which never called `belongings.deserialize()`.

- **CRITICAL: SaveManager overwrote good serialized data with broken versions** — `_serialize_current_level()` called `Level.serialize()` (which properly serializes mobs with mob_id, heaps with item.serialize(), and traps), then OVERWROTE those fields with its own broken versions: mobs without mob_id (all mobs became "rat" on load), heaps with `duplicate(true)` (raw object refs instead of serialized data). Fixed: removed overwrites — SaveManager now uses Level.serialize() data directly, only adding blobs.

- **CRITICAL: Double-deserialization corrupted all entities** — `_deserialize_current_level()` called `Level.deserialize()` (which clears+rebuilds mobs/heaps/traps), then called its own `_deserialize_mobs()`/`_deserialize_heaps()`/`_deserialize_traps()` which cleared everything again and rebuilt with different format expectations. Fixed: removed duplicate deserialization calls.

- **CRITICAL: Cold-start continue destroyed save state** — On fresh app launch, `SaveManager._deserialize_hero()` checked `GameManager.hero != null` and silently skipped hero restoration when null (cold start). Similarly `_deserialize_current_level()` skipped when current_level was null. Then LoadingScene generated a brand new level, destroying all loaded state. Fixed: both methods now CREATE the hero/level objects if null before deserializing.

- **CRITICAL: Continue flow regenerated levels after save/load** — After `SaveManager.load_full_game()` restored `GameManager.current_level`, `LoadingScene._generate_current_level()` didn't check if a valid level was already loaded. It only checked the level cache (previously visited floors), so it generated a fresh level, destroying all saved mob positions, items, traps, and hero position. Fixed: now checks if `current_level` already exists with matching depth and valid map size before regenerating.

- **Plants lost on backtracking** — `Level.serialize()` included heaps, mobs, and traps but NOT plants. When ascending/descending between floors, all plants on a floor were lost. Fixed: added plants serialization (Dictionary format keyed by position) and deserialization with `_create_plant_from_name()` factory supporting all 12 plant types.

- **Wands shot through walls** — `Wand._build_zap_path()` called `lvl.get_passable()` but Level has no such method (it has a `passable` property). The `has_method()` check caused silent fallback to Ballistica.cast_line with a fully-open passable array — wands ignored all walls and obstacles. Fixed: now accesses `lvl.passable` property directly.

## Playability Audit Pass (2026-05-02)
Critical gameplay and stability bugs found through comprehensive codebase audit:

- **CRITICAL: Hero started with no items** — `init_class()` set stats and buffs but never gave the hero starting equipment. Despite class descriptions mentioning specific weapons (worn shortsword, dagger, rapier, etc.), the hero entered the dungeon empty-handed. Fixed: added `give_starting_items()` method to Hero with class-appropriate loadouts:
  - Warrior: worn shortsword + cloth armor + food ration + 2 throwing stones
  - Mage: worn shortsword (staff) + cloth armor + food ration + scroll of identify + 2 throwing stones
  - Rogue: dagger + cloth armor + food ration + cloak of shadows artifact + 2 throwing stones
  - Huntress: gloves + spirit bow + cloth armor + food ration + 2 throwing stones
  - Duelist: rapier + cloth armor + food ration + 2 throwing stones
  Called from both LoadingScene (new game flow) and MainScene (debug path).

- **Memory leak: dead mobs never freed** — Mobs extend Node but are never added to the scene tree. When killed, `_on_death()` removed them from level.mobs and TurnManager, but never freed the Node or its buff children. Over a long run, hundreds of dead mob Nodes would accumulate. Fixed: `_on_death()` now frees all buff children and defers `free()` on itself.

- **Memory leak: old Hero never freed on new game** — Starting a new game after dying created a fresh Hero but never freed the old one. The old Hero Node (with all its buff child nodes) was simply replaced in GameManager and leaked. Fixed: LoadingScene now explicitly frees the old hero before creating a new one.

- **Memory leak: mob Nodes leaked on level transitions** — When descending/ascending, `_cache_current_level()` serialized the level's mobs but left the Node instances in memory. The serialized data was in the cache; the old Nodes were no longer needed. Fixed: `_cache_current_level()` now frees all mob Nodes after serialization.

- **Quest state not saved/loaded** — QuestHandler had `serialize()`/`deserialize()` methods but SaveManager never called them. Saving and loading a game silently lost all quest progress (Ghost quest, Wandmaker quest, Blacksmith quest, Imp quest). Fixed: SaveManager now serializes/deserializes QuestHandler state alongside hero, level, and game manager data.

- **Window overlay blocked all popup input** — `WndBase._setup_overlay()` used deferred `move_child` on a node that wasn't added yet, then deferred `add_child`. This caused the dark overlay to render ON TOP of the window panel, blocking all mouse input to buttons, close button, and content. Inventory, game menu, shop, alchemy, and all other popup windows were unclickable. Fixed: replaced with a deferred `_insert_overlay_behind()` method that correctly adds the overlay and then moves it before the window in draw order.

## Game-Breaking Integration Audit (2026-05-06)
Critical bugs found through deep cross-file integration audit — the game would not have been playable without these fixes:

- **CRITICAL: Game scene never initialized after loading** — `LoadingScene._transition_to_game()` created the GameScene node but never called `load_level()`. No tiles were rendered, no sprites spawned, no FOV computed, no turn system started. The player would see a completely blank screen. Fixed: `_transition_to_game()` now clears TurnManager, registers all actors (hero + mobs via `activate()`), then calls `game_scene.load_level()` with the current level and region.

- **CRITICAL: Level.serialize()/deserialize() missing** — The Level base class had no serialization methods at all, despite PROGRESS.md claiming they existed. Level caching (`_cache_current_level`), save/load, and floor backtracking were all silently broken (the `has_method("serialize")` guard prevented crashes but data was never saved). Fixed: added full `serialize()` method saving depth, entrance/exit, feeling, map, visited, mapped arrays, heaps (with item serialization), mobs (with mob_id/pos/hp/state), traps (via trap.serialize()), and plants. Added `deserialize()` with entity recreation via Generator.create_item(), MobFactory.create_mob(), and trap/plant factory methods.

- **CRITICAL: Hero.earn_xp() missing — XP gain completely broken** — Mob death, Potion of Experience, and Starflower plant all call `hero.earn_xp(amount)`, but Hero had no such method. The `has_method()` guards in some callers prevented crashes, but XP was never awarded and heroes never leveled up. Fixed: added full `earn_xp()` with XP accumulation, multi-level-up support, +5 HP/+1 ATK/+1 DEF per level, full heal on level up, signals, audio, and score bonus.

- **CRITICAL: Hero.take_damage()/heal() not overridden — HUD HP bar stale** — PROGRESS.md claimed these overrides existed, but they were never added. The HUD health bar never reflected damage or healing because `hero_stats_changed` was never emitted. Fixed: added overrides that call `super`, emit `EventBus.hero_stats_changed`, and record damage_taken/healing_done stats.

- **CRITICAL: Hero.get_view_distance() missing** — GameScene calls this for FOV calculation with a `has_method()` guard. Without it, the game fell back to the base constant, so Huntress +2 view distance bonus, Torch buff, Mind Vision, and Blindness effects on FOV were all silently ignored. Fixed: added method returning base distance modified by class (Huntress +2), Torch (+2), Mind Vision (full map), and Blindness (1).

- **CRITICAL: Hero._try_prevent_death() not overridden — death prevention broken** — Berserker rage and Ankh were supposed to prevent death, but Hero never overrode the base method (which returns false). Fixed: added death prevention checking (1) Berserker rage buff try_prevent_death, (2) blessed Ankh (half HP restore), (3) unblessed Ankh (quarter HP, teleport to entrance).

- **CRITICAL: Hero._on_death() missing** — Hero death never emitted `EventBus.hero_died`, so the death screen transition in GameScene was never triggered. Fixed: added override that emits the signal.

- **CRITICAL: Hero serialization missing** — Hero had no serialize()/deserialize() methods, so save/load could never preserve hero state (class, level, XP, stats, belongings). Fixed: added full serialization of all hero-specific fields and belongings.

- **Memory leak: dead mobs never freed** — Mob._on_death() removed mobs from level and TurnManager but never freed the Node or its buff children. Over a long run, hundreds of dead mob Nodes accumulated. Fixed: _on_death() now frees all buff children and defers free() on itself.

- **Missing signal: hero_trampled_grass** — Hero._check_terrain_effects() emitted `EventBus.hero_trampled_grass` but this signal was never declared in EventBus, causing a runtime error when trampling high grass. Fixed: added signal declaration.

- **Trap deserialization mismatch** — Level deserialize used "trap_id" key but trap.serialize() saves the trap name under "type". Also, trap factory used exact string matching that wouldn't match actual trap_name values (e.g., "fire trap" vs "fire_trap"). Fixed: deserialize now reads "type" field, factory uses contains() matching to handle both formats, supports all 8 trap types.

## Next Up
- **Multiplayer** — See REMAINING_WORK.md for detailed plan

## Phase Status
- [x] Core Framework (autoloads, mechanics)
- [x] Phase 1: Dungeon Generation
- [x] Phase 2: Actors & Combat
- [x] Phase 3: Items & Inventory
- [x] Phase 4: Rendering & Visuals
- [x] Phase 5: UI & Menus
- [x] Phase 6: Integration & Polish

## Phase 3 Details (Items & Inventory)
- **item.gd** — Base Item class (RefCounted): item_id, item_name, description, category, level, cursed, identified, stackable, quantity, str_requirement, icon_color. Full stacking (merge/split), identification, upgrade/degrade, curse system, serialization. Duck-typing interface for Belongings (get_damage_range, get_armor_value).
- **heap.gd** — Item piles on ground: HeapType enum (HEAP/FOR_SALE/CRYSTAL_CHEST/LOCKED_CHEST/SKELETON/TOMB/REMAINS), add/remove/peek, serialization
- **generator.gd** — Master loot generation: create_item(item_id) factory dispatches to all specialized class factories via known-ID sets. Weighted category selection, tiered weapon/armor tables by depth, artifact uniqueness tracking. 100+ item IDs supported.
- **recipe.gd** — Alchemy recipe system: 23 recipes (seed→potion, stone→scroll), can_craft(), craft() with ingredient consumption
- **gold.gd** — Gold currency: stackable, auto-adds to GameManager on pickup, not upgradeable
- **Weapons (5 files)**:
  - weapon.gd — Base weapon: tier (1-5), augment (NONE/SPEED/DAMAGE), enchantment slot, SPD damage formula, str requirement scaling, speed/accuracy factors
  - melee_weapon.gd — 25 melee weapons across 5 tiers (5 per tier), reach property (spear/glaive = 2), factory pattern
  - missile_weapon.gd — 12 thrown weapons across 5 tiers, stackable with durability (uses_left), special effects (bolas slow, boomerang returns)
  - spirit_bow.gd — Huntress unique, scales with hero level, fixed str req
  - weapon_enchantment.gd — 9 enchantments: blazing, chilling, shocking, lucky, projecting, unstable, grim, vampiric, elastic
- **Armor (2 files)**:
  - armor.gd — 5 armor tiers (cloth→plate), augment (EVASION/DEFENSE), glyph slot, SPD armor formula, str scaling, evasion/speed factors
  - armor_glyph.gd — 12 glyphs: obfuscation, swiftness, viscosity, stone, repulsion, affection, anti_magic, thorns, potential, brimstone, flow, entanglement
- **Potions**: potion.gd — 14 potions with full drink/shatter effects: healing, strength, mind_vision, invisibility, toxic_gas, liquid_flame, frost, levitation, paralytic_gas, purity, experience, haste, divine_inspiration, mastery
- **Scrolls**: scroll.gd — 14 scrolls with full read effects: identify, upgrade, remove_curse, magic_mapping, teleportation, lullaby, rage, terror, mirror_image, recharging, transmutation, enchantment, retribution, divination. Blindness check prevents reading.
- **Rings**: ring.gd — 11 rings with passive buff system: accuracy, evasion, elements, force, furor, haste, energy, might, sharpshooting, tenacity, wealth. Each creates/manages its own passive buff on equip/unequip.
- **Wands**: wand.gd — 13 wands with charge system: magic_missile, fire_bolt, frost, lightning, disintegration, corrosion, living_earth, blast_wave, prismatic_light, warding, transfusion, corruption, regrowth. Ballistica integration for projectile paths, cursed backfire chance, Mage bonus charges.
- **Artifacts**: artifact.gd — 12 unique artifacts with exp-based leveling: cape_of_thorns, chalice_of_blood, cloak_of_shadows, dried_rose, ethereal_chains, horn_of_plenty, master_thieves_armband, sandals_of_nature, talisman_of_foresight, timekeeper_hourglass, unstable_spellbook, alchemists_toolkit. Each has charge system, activate ability, passive effects.
- **Food**: food.gd — 7 food types: ration, pasty, mystery_meat (random effect), overpriced_ration, small_ration, frozen_carpaccio (random positive buff), meat_pie
- **Bags**: bag.gd — 4 container types: velvet_pouch (stones+seeds), scroll_holder, potion_bandolier, magical_holster (wands)
- **Keys**: key.gd — 4 key types: iron_key, golden_key, crystal_key, skeleton_key. Floor-specific (depth property).
- **Bombs**: bomb.gd — 10 bomb types with fuse/radius/detonation: bomb, fire_bomb, frost_bomb, holy_bomb, wooly_bomb, noisemaker, flashbang, shock_bomb, regrowth_bomb, arcane_bomb
- **Stones**: stone.gd — 11 runestones: enchantment, augmentation, intuition, blast, blink, clairvoyance, deepened_sleep, disarming, fear, flock, shock
- **Spells**: spell.gd — 9 crafted spells: phase_shift, wild_energy, aqua_blast, feather_fall, recycle, alchemize, curse_infusion, reclaim_trap, summon_elemental
- **Misc**: dewdrop.gd (auto-heal on pickup), ankh.gd (death prevention, blessed/unblessed), torch.gd (view distance buff), amulet_of_yendor.gd (victory item)

## Phase 2 Details (Actors & Combat)
- **actor.gd** — Base Actor class with turn system integration (activate/deactivate, energy, position)
- **char.gd** — Base character with HP, combat stats, buff system, attack/defend/damage/heal/die, serialization
- **hero/hero.gd** — Full hero implementation: command pattern actions (move/attack/wait/use_item/interact/ascend/descend), XP/leveling, hunger, class abilities, terrain effects, multiplayer-ready with peer_id and hero_name
- **hero/belongings.gd** — Inventory system: 20-slot backpack, equipment slots (weapon/armor/artifact/ring_l/ring_r/misc), quickslots, stack merging, equip/unequip with callbacks
- **hero/hero_class_data.gd** — Starting stats, descriptions, perks for all 5 classes (Warrior/Mage/Rogue/Huntress/Duelist)
- **mobs/mob.gd** — Base mob with AI state machine (sleeping/wandering/hunting/fleeing/passive), pathfinding, aggro, loot tables, XP value, awareness rolls
- **mobs/mob_factory.gd** — Weighted spawn tables per depth, create_mob(id), create_random_mob(depth), create_boss(depth)
- **Sewer Mobs**: rat, gnoll, crab (high armor), snake (fast, poisons), slime (splits at low HP, acid corrodes)
- **Prison Mobs**: skeleton (explodes on death), thief (steals and flees), guard (chain pull + cripple), necromancer (summons skeletons, stays at range)
- **Caves Mobs**: bat (vampiric heal), brute (enrages at low HP), shaman (ranged lightning + weakness), spinner (poison + webs, flees to heal), dm200 (toxic gas vent)
- **City Mobs**: warlock (ranged dark bolt + lifesteal), monk (fast, multi-hit, disarms), golem (super tanky, teleports target), elemental (burns on hit, fire immune)
- **Halls Mobs**: succubus (charm + teleport), eye (death beam on alignment), scorpio (ranged sting + cripple + poison), ripper (leap attack bonus damage)
- **Bosses**: goo (pumps up, heals in water), tengu (teleport + shuriken, 2 phases), dm300 (gas + charge + pylon heal), dwarf_king (summons undead waves, 3 phases), yog (stationary, spawns fists, laser beam)
- **yog_fist.gd** — Rotting (poison) and Burning (fire) fist sub-bosses
- **Buffs (17)**: buff.gd (base with duration/merge/stat modifiers/hooks), burning, poison, paralysis, invisibility, blindness, weakness, cripple, bleeding, hunger, regeneration, haste, levitation, mind_vision, fury, combo, rooted, charm, terror, amok
- **Blobs (7)**: blob.gd (base with density spreading/decay/per-cell effects), fire_blob (burns terrain + chars), toxic_gas, paralytic_gas, confusion_gas, web_blob (roots then clears), water_of_health (heals + cleanses)
- **Level integration**: Added find_char_at(), get_heroes(), add_mob(), remove_mob(), is_visible_from(), trigger_trap(), unlock_exit(), get_terrain() to level.gd
- **GameManager**: Added heroes[] array alongside hero reference for multiplayer readiness

## Notes
- Project uses Godot 4.5, GDScript, GL Compatibility renderer
- **Target: Browser (HTML5/Web export)** — 1280x720 landscape, keyboard+mouse, "expand" aspect
- All graphics are procedurally generated (no external assets)
- **Multiplayer planned** — architecture supports multiple heroes (command pattern, heroes array, peer_id, clean state/render split)
- Reference: https://github.com/00-Evan/shattered-pixel-dungeon
- Hero actions use command pattern: submit_action({type, ...}) → execute_action() → spend_turn() → TurnManager.hero_action_complete()
- All mobs have unique behaviors matching SPD originals (special attacks, phase transitions, flee conditions)
- Buff system supports: duration, permanent, merge/refresh, stat modifiers (speed/damage/accuracy/evasion/armor), event hooks (on_damage_taken, on_move)
- Blob system uses density-based spreading with per-cell effects on characters and terrain
- Generator dispatches to specialized class factories (MeleeWeapon.create, Potion.create, etc.) — items have full behavior, not just properties
- Seeds are placeholder Items (plants system will be built in Phase 6)
- Artifact uniqueness tracked per run via Generator._generated_artifacts

## Phase 4 Details (Rendering & Visuals)
- **src/tiles/terrain_visuals.gd** — Procedural 16x16 tile generation with 5 region-specific color palettes (Sewers/Prison/Caves/City/Halls). Static texture cache keyed by region+terrain. Draws all 28 terrain types: walls (with brick pattern+mortar), floors, grass (normal/high/furrowed), water (with wave pattern), doors (open/closed/locked/crystal), entrance/exit stairs, embers, chasm, pedestal, barricade, bookshelf (with colored books), alchemy pot, wells, statues, signs, traps (visible/secret/inactive). Wall decorations add moss. Palette provides: wall, wall_dark, wall_highlight, floor, floor_alt, water, water_light, grass, grass_tall, door, special, embers.
- **src/tiles/tile_map_manager.gd** — Renders full 32x32 level grid using pooled Sprite2D nodes (1024 sprites). Provides: setup(), render_full(), render_changed() (diff-based), update_tile_at(), cell_to_world(), world_to_cell(), set_region(). Tracks rendered terrain per cell to skip redundant texture updates.
- **src/tiles/fog_of_war.gd** — Three-state FOV overlay using Image+ImageTexture (512x512 px). States: UNSEEN (black opaque), VISITED (55% black), VISIBLE (transparent). Supports DARK level feeling (25% dim on visible cells). Efficient diff-based update_visibility() compares against previous frame's visible/visited arrays. Full reveal for magic mapping scroll.
- **src/sprites/char_sprite.gd** — Base character sprite class (Node2D with Sprite2D child). 16x16 procedural generation via _draw_character() virtual. Animation system: move_to() with tween, play_attack() with lunge+return, flash() for damage feedback, play_death() with fade+shrink. Movement tween uses EASE_OUT/QUAD. Attack lunge uses TRANS_BACK. Self-destructs on death animation complete.
- **src/sprites/hero_sprite.gd** — Hero-specific sprites with class-based color schemes and distinct silhouettes. Warrior: heavy helm+plate+sword+gold trim. Mage: hooded robes+staff+orb. Rogue: cowl+cloak+dagger. Huntress: hair+tunic+bow+quiver. Duelist: feathered hat+sash+rapier. Each class has body/accent/eye/weapon/detail colors.
- **src/sprites/mob_sprite.gd** — Mob sprites with 26 mob-type visual definitions. 6 shape types: humanoid, small (rats/crabs), large (guards/golems), beast (4-legged), flying (wings), blob (amorphous). Each mob has body/accent/eye colors. All shapes procedurally drawn with distinct silhouettes.
- **src/sprites/item_sprite.gd** — Item ground sprites for 12 categories. Draws: swords (diagonal blade), armor (chestplate), wands (staff+glowing tip), rings (circle+gem), artifacts (diamond glow), potions (bottle+liquid), scrolls (rolled+seal), stones (rune-marked), seeds (sprouting), food (ration), gold (coin stack), misc (sack). Pickup animation (float+fade), drop animation (bounce).
- **src/effects/effect_manager.gd** — Central effect spawner with pool limits (50 effects, 20 damage numbers). API: show_damage(), show_heal(), show_status(), shoot_projectile(), particle_burst(), ring_effect(), lightning(), screen_flash(). All effects self-destruct. Tracks active count to prevent overflow.
- **src/effects/damage_number.gd** — Floating text that rises and fades. Supports damage (red), crits (orange+scaled up), heals (green +N), and arbitrary status text. Random X offset prevents stacking. 0.8s duration.
- **src/effects/projectile_effect.gd** — Point-to-point projectile with trail. Configurable color and speed. Draws dot + fading trail of past positions. Brief flash at impact. Uses _draw() for custom rendering.
- **src/effects/particle_burst.gd** — Burst of N particles with randomized angles/speeds. Supports drag (0.92/frame), fade over lifetime. Also supports ring_effect mode (expanding arc). Uses _draw() for custom rendering.
- **src/effects/lightning_effect.gd** — Jagged bolt between two points using randomized segments with jitter perpendicular to direction. Flicker effect (on/off cycling), regenerates segments each flash for jitter feel. Branch bolts for added detail. 0.3s duration with alpha fade.
- **src/scenes/game_camera.gd** — Smooth-follow Camera2D. Config: follow_speed, zoom (1.5x–5.0x, default 3.0x), mouse wheel zoom, screen shake with intensity decay. Clamps to map bounds. get_cell_under_mouse() for input handling. snap_to_target() for instant positioning on level load.
- **src/scenes/game_scene.gd** — Main gameplay orchestrator. Creates layers: TileMap (z=-10), EntityLayer (z=0), EffectManager (z=50), FogOfWar (z=100), Camera. Manages sprite dictionaries for heroes/mobs/items. Input handling: click-to-move/attack, keyboard movement (arrows, numpad, vi keys hjkl), space=wait, <>= stairs. Bridges hero command pattern to visual animations. refresh_after_turn() updates FOV, tiles, entity visibility, camera. Connects to EventBus for reactive effects (shake on damage, particles on mob death, tile update on door open).
- **src/scenes/main_scene.gd** — Entry point that starts a new game, generates level 1, registers actors with TurnManager, creates GameScene, and kicks off the turn loop. Placeholder until Phase 5 title screen.
- **src/scenes/game_scene.tscn** — Minimal scene file for GameScene node.
- All rendering uses 16x16 pixel art scale with nearest-neighbor filtering (project.godot: default_texture_filter=0, snap_2d_transforms/vertices)
- Camera default zoom 3.0x shows approximately 26x15 tiles on 1280x720 viewport — good dungeon overview
- Input: click to move/attack/interact, keyboard arrows+numpad+vi keys, space/period=wait, mouse wheel=zoom
- Entity visibility tied to FOV: mobs only visible in lit cells, items visible in visited or visible cells

## Phase 5 Details (UI & Menus)
- **src/ui/hud.gd** — Main HUD controller (CanvasLayer layer 10). Layout: top bar (depth/region/turn/gold, 32px), left game log (220px), right sidebar (200px), bottom toolbar (40px), centered window layer for popups. Creates and manages all panels. show_window()/close_window() API for popup windows. Connects to EventBus for reactive updates.
- **src/ui/status_pane.gd** — Right sidebar panel. Hero portrait (class-colored rect), HP bar (green/yellow/red), XP bar, STR/depth display, 6 equipment slots (weapon/armor/artifact/ring_l/ring_r/misc as ItemSlots), active buffs row. Updates via EventBus.hero_stats_changed.
- **src/ui/toolbar.gd** — Bottom bar with 5 icon buttons: Inventory [I], Map [M], Wait [Space], Search [S], Settings [Esc]. Handles keyboard shortcuts via _unhandled_input. Emits action signals.
- **src/ui/game_log_display.gd** — Left panel ScrollContainer with VBoxContainer of RichTextLabels. Groups messages by turn. Auto-scrolls to bottom. Shows ~20 messages. Connects to MessageLog.message_added.
- **src/ui/minimap.gd** — 64x64 pixel overview (32x32 cells at 2px each). Terrain colors, hero blink, mob dots in visible cells. Toggleable via update_map()/toggle_visible().
- **src/ui/components/icon_button.gd** — 32x32 procedural icon button. 8 icon types, hover highlight, press animation, disabled state.
- **src/ui/components/item_slot.gd** — 40x40 inventory slot. Category-specific icons, quantity badge, level indicator, cursed/selected borders. slot_clicked/slot_right_clicked signals.
- **src/ui/components/health_bar.gd** — Tweened horizontal bar. Auto-colors by percentage. Optional text overlay. Configurable bar_color for XP bars.
- **src/ui/components/buff_icon.gd** — 20x20 colored circle with buff letter. Flashes when expiring. Tooltip with name/duration.
- **src/ui/components/toast.gd** — CanvasLayer notification system. Static show_toast() API. Queue management (max 5). Slide-in/fade-out animation.
- **src/ui/windows/wnd_base.gd** — Base window: dark overlay, title bar, draggable, modal, Escape to close, fade+scale animations. Virtual _build_content()/_on_close().
- **src/ui/windows/wnd_inventory.gd** — Equipment row (6 slots), gold display, filter tabs (All/Weapons/Armor/Potions/Scrolls/Other), sort, 5x4 item grid. Opens WndItem on click.
- **src/ui/windows/wnd_item.gd** — Item detail: colored name, description, stats, context-sensitive action buttons (Equip/Use/Drop/Throw/Quickslot).
- **src/ui/windows/wnd_hero_info.gd** — Stats window: class/subclass, portrait, stat grid (level/XP/HP/HT/STR/attack/defense/damage/armor), buffs list, run statistics.
- **src/ui/windows/wnd_game.gd** — Game menu: Resume, Settings, Save & Quit, Quit Without Saving. Shows depth/region/hero summary.
- **src/ui/windows/wnd_shop.gd** — Shop: items for sale with prices, buy/sell interface, gold display.
- **src/ui/windows/wnd_alchemy.gd** — 3 ingredient slots, recipe lookup via Recipe.find_recipe(), result preview, Brew button.
- **src/ui/windows/wnd_journal.gd** — Tabs: Notes (keys/quests), Catalog (discovered items by category), Guide (gameplay tips).
- **src/scenes/title_scene.gd** — Title screen: procedural dungeon background with flickering torches, game title, 4 buttons (New Game/Continue/Rankings/About), keyboard nav (up/down/Enter).
- **src/scenes/hero_select_scene.gd** — 5 class panels horizontal: class name, colored silhouette portrait, starting stats. Gold border selection, left/right/Enter keyboard nav.
- **src/scenes/loading_scene.gd** — Transition screen: depth number, region name, flavor text, animated torch. Handles new game setup (creates hero, generates level) and continue flow. Auto-transitions after generation.
- **src/scenes/rankings_scene.gd** — Scrollable past runs list from user://rankings.dat. Shows rank/class/depth/result/score/gold. Back and Clear buttons.
- **src/scenes/surface_scene.gd** — Victory scene: sky background, sun, gold sparkle particles, score breakdown, auto-saves ranking.
- **src/scenes/death_scene.gd** — Death screen: procedural tombstone, cause of death, stats summary, score, 3 buttons (Menu/Try Again/Rankings). Auto-saves run.
- **src/scenes/main_scene.gd** — Updated: now launches TitleScene on startup instead of auto-starting a game.
- Layout: 1280x720 landscape, top bar + left log + right sidebar + bottom toolbar, game viewport in center
- Keyboard shortcuts: I=inventory, M=map, Space=wait, S=search, Esc=settings, arrow/numpad/vi=movement
- Game flow: Title → Hero Select → Loading → Game (with HUD) → Death/Surface → Rankings → Title

## Phase 6 Details (Integration & Polish)
- **src/balance.gd** — Centralized balance reference: XP curve, mob stat table (all 22+ mobs), hero starting stats, weapon/armor damage/DR formulas with tier tables, combat hit/damage formulas, hunger/food values, gold/price scaling, strength requirement progression, healing rates, buff durations, boss parameters, loot generation weights, depth/region mapping. Single file for all tuning numbers.
- **Plants system** — 8 plant types (Sungrass, Earthroot, Fadeleaf, Firebloom, Icecap, Sorrowmoss, Stormvine, Dreamfoil) with seed-to-plant growth, trample activation effects, terrain integration
- **NPC quest chain** — Sad Ghost (fetch quest, weapon/armor reward), Old Wandmaker (wand reward), Ambitious Imp (ring reward), Blacksmith (reforge service). Quest tracking in GameManager.
- **Audio framework** — AudioManager autoload with procedural SFX generation (attack, hit, death, pickup, levelup, door, trap, potion, scroll, gold, equip, menu), ambient dungeon loop, region-specific tonal variation
- **Save/Load system** — SaveManager autoload: full game state serialization (hero, level terrain, mobs, items, buffs, quest progress), user://save_game.dat, rankings persistence in user://rankings.dat
- **Web export** — export_presets.cfg for HTML5/Web with PWA support, GL Compatibility renderer, audio mix rate 44100, pixel-snap settings, canvas_items stretch mode
- **REMAINING_WORK.md** — Comprehensive gap analysis: known missing features (subclasses, mimics, piranhas, badges, localization, real art/audio), detailed multiplayer implementation plan (architecture, turn system, network model, UI changes), web export/deploy instructions, testing recommendations
