class_name FireImbue
extends Buff
## FireImbue: imbues attacks with fire, matching upstream `FireImbue.java`
## (Elixir of Dragon's Blood; Warden firebloom trample grants 30% duration).
## Duration: 50 turns. On proc (upstream `Char.attack` after damage): 50%
## chance to reignite Burning on the target. Each turn, grass under the owner
## is scorched to embers. Grants immunity to Burning while active and strips
## any existing Burning on attach.

const BASE_DURATION: float = 50.0

func _init() -> void:
	buff_id = "FireImbue"
	buff_name = "Fire Imbue"
	buff_type = BuffType.POSITIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(1.0, 0.5, 0.0)

## Upstream `immunities.add(Burning.class)`.
func immunities() -> Array:
	return ["Burning"]

func on_attach() -> void:
	# Upstream attachTo: Buff.detach(target, Burning.class).
	if target != null and target.has_method("remove_buff_by_id"):
		target.remove_buff_by_id("Burning")
	if MessageLog and target:
		MessageLog.add_positive("%s's attacks are imbued with fire!" % target.name)

## Upstream act(): grass under the owner is scorched to embers each turn.
func on_turn() -> void:
	if target == null or not is_instance_valid(target):
		return
	var level: Variant = GameManager.current_level if GameManager else null
	if level == null or not level.has_method("terrain_at"):
		return
	var pos: int = int(target.pos)
	if pos >= 0 and level.terrain_at(pos) == ConstantsData.Terrain.GRASS:
		level.set_terrain(pos, ConstantsData.Terrain.EMBERS)

## Called after the owner deals attack damage (upstream `FireImbue.proc`):
## 50% chance to reignite Burning on the defender.
func proc(defender: Node) -> void:
	if defender == null or not defender.get("is_alive"):
		return
	if randi_range(0, 1) != 0:
		return
	var existing: Node = defender.get_buff("Burning") if defender.has_method("get_buff") else null
	if existing != null and existing.has_method("reignite"):
		existing.reignite()
	elif defender.has_method("add_buff"):
		defender.add_buff(Burning.new())

func description() -> String:
	return "Attacks have a 50%% chance to set enemies on fire (%s turns left)." % disp_turns(time_left)
