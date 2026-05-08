class_name EventBusNode
extends Node
## Central signal bus for decoupled communication between game systems.
## All game-wide events are emitted and listened to through this singleton.

# --- Hero Signals ---
## Emitted when the hero moves to a new cell. payload: new_pos (int)
@warning_ignore("unused_signal")
signal hero_moved(new_pos: int)
## Emitted when the hero takes damage. payload: amount (int), source (Variant)
@warning_ignore("unused_signal")
signal hero_damaged(amount: int, source: Variant)
## Emitted when the hero's HP reaches zero.
@warning_ignore("unused_signal")
signal hero_died
## Emitted when the hero's stats change (HP, STR, EXP, etc.).
@warning_ignore("unused_signal")
signal hero_stats_changed

# --- Combat Signals ---
## Emitted when any mob is defeated. payload: mob_pos (int), mob_name (String)
@warning_ignore("unused_signal")
signal mob_defeated(mob_pos: int, mob_name: String)
## Emitted when a mob dies (passes the mob object for loot/effects).
@warning_ignore("unused_signal")
signal mob_died(mob: Variant)
## Emitted when a mob takes damage from hero attack. payload: mob_pos (int), amount (int)
@warning_ignore("unused_signal")
signal mob_damaged(mob_pos: int, amount: int)
## Emitted when the hero misses an attack. payload: mob_pos (int)
@warning_ignore("unused_signal")
signal hero_attack_missed(mob_pos: int)
## Emitted when a disguised mob reveals itself (mimic).
@warning_ignore("unused_signal")
signal mob_revealed(mob: Variant)
## Emitted when a weapon enchantment procs during combat.
@warning_ignore("unused_signal")
signal enchantment_proc(enchant_id: String, attacker_pos: int, defender_pos: int)
## Emitted when an armor glyph procs during combat.
@warning_ignore("unused_signal")
signal glyph_proc(glyph_id: String, wearer_pos: int, attacker_pos: int)

# --- Item Signals ---
## Emitted when the hero picks up an item. payload: item_name (String)
@warning_ignore("unused_signal")
signal item_picked_up(item_name: String)
## Emitted when the hero uses/consumes an item. payload: item_name (String)
@warning_ignore("unused_signal")
signal item_used(item_name: String)
## Emitted when the hero equips an item. payload: item_name (String), slot (String)
@warning_ignore("unused_signal")
signal item_equipped(item_name: String, slot: String)
## Emitted when the hero unequips an item. payload: item_name (String), slot (String)
@warning_ignore("unused_signal")
signal item_unequipped(item_name: String, slot: String)

# --- Level / World Signals ---
## Emitted when the player changes levels. payload: new_depth (int)
@warning_ignore("unused_signal")
signal level_changed(new_depth: int)
## Emitted when a door is opened. payload: pos (int)
@warning_ignore("unused_signal")
signal door_opened(pos: int)
## Emitted when a trap is triggered. payload: pos (int), trap_name (String)
@warning_ignore("unused_signal")
signal trap_triggered(pos: int, trap_name: String)

# --- Economy ---
## Emitted when the hero collects gold. payload: amount (int), total (int)
@warning_ignore("unused_signal")
signal gold_collected(amount: int, total: int)

# --- Persistence ---
## Emitted after the game has been saved.
@warning_ignore("unused_signal")
signal game_saved
## Emitted after a game has been loaded.
@warning_ignore("unused_signal")
signal game_loaded

# --- UI / Misc ---
## Emitted when any important game event occurs for the badge/achievement system.

@warning_ignore("unused_signal")
signal game_event(event_name: String, event_data: Dictionary)

# --- Badges ---
## Emitted when a badge/achievement is unlocked.
@warning_ignore("unused_signal")
signal badge_unlocked(badge_id: String)

# --- Quests ---
## Emitted when a quest state changes.
@warning_ignore("unused_signal")
signal quest_updated(quest_id: String, state: String)

# --- Environment ---
## Emitted when the hero tramples grass (for Sandals of Nature / seed drops).
@warning_ignore("unused_signal")
signal hero_trampled_grass(pos: int)

# --- Targeting ---
## Emitted to enter targeting mode (throw, zap). payload: item, max_range, callback
@warning_ignore("unused_signal")
signal enter_targeting(item: Variant, max_range: int, callback: Callable)
## Emitted to cancel targeting mode.
@warning_ignore("unused_signal")
signal cancel_targeting

# --- Boss Fight ---
## Emitted when a boss fight begins. Triggers boss HP bar display.
@warning_ignore("unused_signal")
signal boss_fight_started(boss_name: String, boss_hp: int)
## Emitted when a boss takes damage.
@warning_ignore("unused_signal")
signal boss_damaged(current_hp: int, max_hp: int)
## Emitted when a boss is defeated.
@warning_ignore("unused_signal")
signal boss_defeated

@warning_ignore("unused_signal")
signal npc_face_hero(npc: Variant)
@warning_ignore("unused_signal")
signal show_window(window: Variant)
