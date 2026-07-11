# System Audit Ledger

Methodical pass over every system. Process in order (top = highest priority).
Status: `pending` | `in-progress` | `done`. When done, add report link + verdict.

Pointer (next to evaluate): **S12**

| ID | System | Primary paths | Status | Verdict / report |
|----|--------|---------------|--------|------------------|
| S01 | Persistence / SaveManager | `src/autoloads/save_manager.gd`, `docs/memory/persistence-notes.md` | done | needs-hardening — [report](reports/S01-persistence.md). Object graph solid; durability thin (non-atomic write, no autosave) + ~200 lines dead serialization. |
| S02 | Hero & belongings | `src/actors/hero/` | done | needs-hardening — [report](reports/S02-hero.md). Turn loop/leveling/save graph solid; class-subclass identity largely stubbed (Mage no staff, Warrior/Rogue passives `pass`, Champion dual-wield unwired) + inert groundwork talents. |
| S03 | Actor / Char combat core | `src/actors/actor.gd`, `src/actors/char.gd` | done | needs-hardening — [report](reports/S03-combat-core.md). Combat resolution faithful & clean, but Char has no combat-state serializer (subclasses hand-roll hp/stats) + two SPD-fidelity gaps: uniform damage roll (not NormalIntRange) and invisible-only surprise hits. |
| S04 | Turn scheduling | `src/autoloads/turn_manager.gd` | done | needs-hardening — [report](reports/S04-turn-scheduling.md). Cooldown rebasing + hero-pause loop correct, but no persisted scheduling state (cooldowns reset on save/load), cached `speed` can go stale silently, and the async mob-pacing layer is dead code (`MOB_ACTION_DELAY` const 0.0). |
| S05 | Mobs & AI | `src/actors/mobs/` | done | needs-hardening — [report](reports/S05-mobs-ai.md). State machine + save/relink (necromancer↔skeleton) faithful, but Swarm split *duplicates* HP instead of halving (balance/XP bug), `heroes[0]` targeting ignores distance, and several inert fields. Auto-fixed: removed dead `_path`. |
| S06 | Buffs | `src/actors/buffs/` | done | needs-hardening — [report](reports/S06-buffs.md). Base lifecycle + save/relink solid, but modifier dispatch is inconsistent: Fury 1.5× double-applies (2.25× melee), `get_speed()` ignores `modify_speed()` (Sleep/Dread/MonkFlurry speed hooks dead), Doom is a wrong timer-kill, Gladiator Combo inert, Frozen freezes multiple potions. Auto-fixed: removed dead no-op MonkFlurry.on_turn. |
| S07 | Level base & grid | `src/levels/level.gd`, `src/levels/regular_level.gd` | done | needs-hardening — [report](reports/S07-level-base-grid.md). Grid/FOV/AStar core faithful & clean, but mob population is thin: `mob_spawn_positions` under-spawns (decrements on failed placements, single-pos fallback, unimplemented 2nd-mob roll), no periodic respawn, mimic spawn discards its item. Perf: point LOS casts a full FOV (Ballistica exists), O(n) mob/heap scans. `rooms` not serialized. No auto-fixes (both files in TRUNCATED_FILES.txt). |
| S08 | Level generation | `src/levels/builders/`, `src/levels/painters/`, `src/levels/rooms/` | done | needs-hardening — [report](reports/S08-level-generation.md). Geometry/painting clean, but the door layer is dead: builder always leaves a 2-tile gap so `connect_adjacent` never fires → `connected` empty → no DOOR/LOCKED_DOOR painted (vaults/armories unlocked, shop/garden doors missing). Plus tunnel `pair_key` int64 overflow risk + dead doorframe helpers. No safe auto-fixes. |
| S09 | Region & boss levels | `src/levels/*_level.gd`, `src/levels/*_boss_level.gd` | done | needs-hardening — [report](reports/S09-region-boss-levels.md). Depth→class routing + boss seal/unlock (`unlock_exit` on death) faithful, but HallsLevel drops its whole trap tier (no `_create_random_trap` → tier-1 fallback), boss arenas skip traversability validation (unconditional `return true`, no factory retry), Halls/Last chasm-ring lets knockback eject the hero mid-fight, and the seal is down-exit-only (ascent unblocked, `goo.floor_sealed` dead). No safe auto-fixes (P1 fix is behavioral + halls_level.gd truncated). |
| S10 | Traps | `src/levels/traps/` | done | needs-hardening — [report](reports/S10-traps.md). Base lifecycle + script-path serialize faithful, but `disarming_trap` fires `drop_item` with swapped args (permanent weapon loss), paralytic/fire traps have inert `pass` buffs (Paralysis/Burning never applied), and 7 trap classes (Frost/Blazing/Disarming/Pitfall/Cursing/Flock/Paralytic) are wired into no generation pool = dead content. No safe auto-fixes (all behavioral). |
| S11 | Level features | `src/levels/features/` | done | needs-hardening — [report](reports/S11-level-features.md). `door.gd` is live but opens LOCKED_DOOR with the wrong key (`golden`, should be `iron` → iron keys useless) and door-open logic is triplicated; `chasm.gd` is entirely dead while the live inline chasm path (`hero.gd:662`) is instant-death instead of SPD fall-to-next-floor. No safe auto-fixes (both files in TRUNCATED_FILES.txt, all findings behavioral). |
| S12 | Item base & Generator | `src/items/item.gd`, `src/items/generator.gd`, `src/items/heap.gd` | pending | — |
| S13 | Weapons / armor / glyphs / enchants | `src/items/weapons/`, `src/items/armor/` | pending | — |
| S14 | Wands & staffs | `src/items/wands/` | pending | — |
| S15 | Potions & scrolls | `src/items/potions/`, `src/items/scrolls/` | pending | — |
| S16 | Rings & artifacts | `src/items/rings/`, `src/items/artifacts/` | pending | — |
| S17 | Consumables & misc items | `src/items/seeds/`, `src/items/food/`, `src/items/bombs/`, `src/items/stones/`, `src/items/spells/` | pending | — |
| S18 | Bags & inventory containers | `src/items/bags/`, `src/items/keys/` | pending | — |
| S19 | Plants | `src/plants/` | pending | — |
| S20 | Blobs (gases/liquids) | `src/actors/blobs/` | pending | — |
| S21 | NPCs & quests | `src/actors/npcs/` | pending | — |
| S22 | Movement / pathfinding / FOV | `src/mechanics/pathfinder.gd`, `ballistica.gd`, `shadow_caster.gd`, `auto_walk_coordinator.gd` | pending | — |
| S23 | Input & targeting | `src/mechanics/input_coordinator.gd`, `targeting_coordinator.gd` | pending | — |
| S24 | Transitions (floor/run) | `src/mechanics/floor_transition_coordinator.gd`, `run_transition_coordinator.gd` | pending | — |
| S25 | Feedback coordinators | `src/mechanics/scene_feedback_coordinator.gd`, `scene_visual_coordinator.gd`, `environment_feedback_coordinator.gd` | pending | — |
| S26 | GameManager & run lifecycle | `src/autoloads/game_manager.gd` | pending | — |
| S27 | EventBus | `src/autoloads/event_bus.gd` | pending | — |
| S28 | Scene flow | `src/autoloads/scene_manager.gd`, `src/scenes/` | pending | — |
| S29 | Catalogs & profile | `src/autoloads/badges.gd`, `discovery_catalog.gd`, `item_catalog.gd`, `item_appearance.gd`, `player_profile.gd`, `constants.gd` | pending | — |
| S30 | Audio & MessageLog | `src/autoloads/audio_manager.gd`, `message_log.gd` | pending | — |
| S31 | Networking & online sync | `src/autoloads/network_manager.gd`, `src/mechanics/online_*.gd` | pending | — |
| S32 | Sprites | `src/sprites/` | pending | — |
| S33 | Tiles & fog | `src/tiles/` | pending | — |
| S34 | Effects | `src/effects/` | pending | — |
| S35 | HUD / toolbar / status | `src/ui/hud.gd`, `toolbar.gd`, `status_pane.gd`, `minimap.gd`, `boss_hp_bar.gd` | pending | — |
| S36 | Windows | `src/ui/windows/` | pending | — |
| S37 | UI components | `src/ui/components/`, `src/ui/ui_utils.gd` | pending | — |

37 systems. Completed: 11 / 37.
