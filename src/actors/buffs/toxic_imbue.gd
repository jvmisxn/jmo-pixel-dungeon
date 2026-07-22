class_name ToxicImbue
extends Buff
## Surrounds the owner with a self-sustaining cloud of Toxic Gas each turn and
## grants immunity to Poison / Toxic Gas, matching upstream `ToxicImbue.java`.
##
## Source (`ToxicImbue.act()`): while active it seeds 6 units of `ToxicGas` into
## every non-solid `NEIGHBOURS8` cell around the owner, and any solid neighbour's
## share is redirected into the owner's own cell (`centerVolume` starts at 6 and
## grows by 6 per solid neighbour); the accumulated centre volume is then seeded
## on the owner's cell. Upstream also `immunities.add(ToxicGas)` /
## `immunities.add(Poison)` and strips any existing Poison on attach, so the
## owner walks unharmed inside their own cloud.
##
## Divergences (documented): upstream keeps its immunity for 5 extra turns after
## the gas stops (`left <= -5` detach); this port expires the buff — and the
## immunity — when `time_left` reaches 0. Owner-cell terrain is treated with the
## same `terrain_is_solid` test the sibling plant/trap code uses rather than a
## dedicated `Dungeon.level.solid[]` flag map, and no gas SFX/particles are
## modelled.

const BASE_DURATION: float = 50.0
## Base gas volume seeded on the owner's own cell each turn.
const CENTER_BASE_VOLUME: float = 6.0
## Gas volume seeded into each open neighbouring cell each turn.
const NEIGHBOUR_VOLUME: float = 6.0

func _init() -> void:
	buff_id = "ToxicImbue"
	buff_name = "Toxic Imbue"
	buff_type = BuffType.POSITIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.4, 0.8, 0.2)

## Owner is immune to its own gas (and any other Poison/Toxic Gas) while active.
## Both the blob id (`toxic_gas`) and the Poison buff id are listed so the
## immunity holds whether protection is queried by blob or by the applied buff.
func immunities() -> Array:
	return ["Poison", "toxic_gas", "ToxicGas"]

func on_attach() -> void:
	# Upstream clears any existing Poison the moment the imbue attaches.
	if target != null and target.has_method("remove_buff_by_id"):
		target.remove_buff_by_id("Poison")
	if MessageLog and target != null:
		MessageLog.add_positive("A cloud of toxic gas billows around you!")

func on_turn() -> void:
	if target == null or not is_instance_valid(target):
		return
	var level: Variant = GameManager.current_level if GameManager else null
	if level == null or not level.has_method("add_blob"):
		return

	var origin: int = int(target.pos)
	var center_volume: float = CENTER_BASE_VOLUME
	for dir: int in ConstantsData.DIRS_8:
		var adj: int = origin + dir
		# Redirect a blocked neighbour's share to the centre: out-of-bounds,
		# column-edge row wraps, and solid cells all fold back into `origin`.
		if adj < 0 or adj >= Level.LEN or absi(adj % Level.W - origin % Level.W) > 1:
			center_volume += NEIGHBOUR_VOLUME
			continue
		if level.has_method("terrain_at") and ConstantsData.terrain_is_solid(level.terrain_at(adj)):
			center_volume += NEIGHBOUR_VOLUME
			continue
		level.add_blob(ToxicGas.new(), adj, NEIGHBOUR_VOLUME)
	level.add_blob(ToxicGas.new(), origin, center_volume)

func description() -> String:
	return "You are wreathed in toxic gas, immune to poison (%s)." % disp_turns(time_left)
