class_name NPC
extends Mob
## Base class for all non-hostile NPCs. NPCs are passive mobs that can be
## interacted with by the hero, typically offering quests and rewards.

# --- Quest State ---
## Unique quest identifier for this NPC.
var quest_id: String = ""
## Whether the NPC's quest has been accepted by the hero.
var quest_active: bool = false
## Whether the quest objective has been fulfilled.
var quest_complete: bool = false
## Lines of dialogue, indexed by quest state.
var dialogue_lines: Array[String] = []

# --- NPC Identity ---
var npc_name: String = "NPC"
var _last_interacting_owner_peer_id: int = 1

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

func _init() -> void:
	super._init()
	state = AIState.PASSIVE
	mob_name = npc_name

# ---------------------------------------------------------------------------
# Turn System
# ---------------------------------------------------------------------------

## NPCs simply spend their turn doing nothing. They never move or attack.
func act() -> void:
	act_buffs()
	spend_turn()

# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

## Called when the hero interacts with this NPC (e.g., bumps into them).
## Subclasses override this to provide quest logic.
func interact(hero: Variant) -> void:
	if hero == null:
		return
	_remember_interacting_hero(hero)
	if EventBus:
		EventBus.npc_interacted.emit(npc_name)
	var line: String = get_dialogue()
	if line != "":
		_deliver_message(line, "info", hero)

## Returns the appropriate dialogue line based on the current quest state.
func get_dialogue() -> String:
	if quest_complete and dialogue_lines.size() > 2:
		return dialogue_lines[2]
	elif quest_active and dialogue_lines.size() > 1:
		return dialogue_lines[1]
	elif dialogue_lines.size() > 0:
		return dialogue_lines[0]
	return ""

# ---------------------------------------------------------------------------
# Combat Override — NPCs are non-hostile
# ---------------------------------------------------------------------------

## NPCs never attack. If something tries to make them attack, refuse.
func attack(_target_char: Char, _dmg_multi: float = 1.0, _dmg_bonus: float = 0.0, _acc_multi: float = 1.0) -> bool:
	return false

## NPCs are invulnerable — they take no damage from any source.
## Matches original NPC.damage() which does nothing.
func take_damage(_dmg: int, _source: Variant = null) -> int:
	return 0

## NPCs cannot receive buffs — matches original NPC.add(Buff) returning false.
func add_buff(buff_node: Node) -> Node:
	if buff_node != null and not buff_node.is_queued_for_deletion():
		buff_node.queue_free()
	return null

## NPCs have infinite evasion — they can never be hit.
func evasion() -> int:
	return 1000000  # INFINITE_EVASION equivalent

## NPCs should never hunt or flee. Force passive if state is changed externally.
func _set_state(new_state: AIState) -> void:
	# NPCs are always passive
	super._set_state(AIState.PASSIVE)

# ---------------------------------------------------------------------------
# Death Override — NPCs don't drop loot or give XP normally
# ---------------------------------------------------------------------------

func _on_death(source: Variant) -> void:
	_deliver_message("The %s fades away..." % mob_name, "warning")
	if level and level.has_method("remove_mob"):
		level.remove_mob(self)

func _remember_interacting_hero(hero: Variant) -> void:
	if hero == null:
		return
	_last_interacting_owner_peer_id = int(ConstantsData.get_prop(hero, "owner_peer_id", 1))

func _deliver_message(text: String, kind: String = "info", hero: Variant = null) -> void:
	var trimmed_text: String = text.strip_edges()
	if trimmed_text.is_empty():
		return
	var owner_peer_id: int = _get_message_owner_peer_id(hero)
	if NetworkManager != null and NetworkManager.has_method("is_host") and NetworkManager.is_host():
		var local_peer_id: int = NetworkManager.get_local_peer_id() if NetworkManager.has_method("get_local_peer_id") else 1
		if owner_peer_id != local_peer_id and NetworkManager.has_method("send_ui_event_to_peer"):
			NetworkManager.send_ui_event_to_peer(owner_peer_id, {
				"type": "npc_message",
				"text": trimmed_text,
				"message_kind": kind,
			})
			return
	_log_message_local(trimmed_text, kind)

func _get_message_owner_peer_id(hero: Variant = null) -> int:
	if hero != null:
		return int(ConstantsData.get_prop(hero, "owner_peer_id", 1))
	if _last_interacting_owner_peer_id > 0:
		return _last_interacting_owner_peer_id
	return 1

func _log_message_local(text: String, kind: String) -> void:
	if MessageLog == null:
		return
	match kind:
		"positive":
			MessageLog.add_positive(text)
		"warning":
			MessageLog.add_warning(text)
		"negative":
			MessageLog.add_negative(text)
		_:
			MessageLog.add_info(text)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["quest_id"] = quest_id
	data["quest_active"] = quest_active
	data["quest_complete"] = quest_complete
	data["npc_name"] = npc_name
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	quest_id = str(data.get("quest_id", quest_id))
	quest_active = bool(data.get("quest_active", quest_active))
	quest_complete = bool(data.get("quest_complete", quest_complete))
	npc_name = str(data.get("npc_name", npc_name))
	mob_name = npc_name

func resolve_post_load(_level_ref: Level) -> void:
	if quest_id != "" and QuestHandler:
		QuestHandler._register_npc(self)
