class_name Ghoul
extends Mob
## Upstream Ghoul.java (Dwarven City): spawns with a partner ghoul on its
## first turn, and when downed near another living ghoul it does not die —
## a GhoulLifeLink on the nearby ghoul revives it after 5*times_downed turns
## at 1/10 HP. Killing every nearby ghoul (or downing it over a chasm) makes
## the death stick.
##
## Port adaptations: stats use the port's re-tuned scale (HP is upstream's
## 45; attack/defense/damage follow the port's Monk/Warlock tuning); the
## partner-follow Sleeping/Wandering AI variants are not ported.

## Set once this ghoul has produced (or is) a partner, so pairs do not chain.
var partner_spawned: bool = false
## True while lying crumpled under a GhoulLifeLink (not in level.mobs).
var downed: bool = false
## How many times this ghoul has been downed (revive takes 5*times_downed).
var times_downed: int = 0

func _init() -> void:
	super._init()
	mob_id = "ghoul"
	mob_name = "Ghoul"
	description = "Ghouls are dwarves whose bodies have refused to properly die, and continue lurching about while their minds decay. As their bodies are already dead, ghouls are able to lie low and recover from the most grievous wounds, so long as one of their kin is nearby.\n\nGhouls are weak on their own, but always work in pairs."
	setup(45, 20, 12, 8, 14, 4)
	xp_value = 5
	max_level = 20
	awareness = 0.25
	aggro_range = 8
	loot_table = [{"item_id": "gold", "chance": 0.2}]
	_properties = ["UNDEAD"]


func act() -> void:
	# Upstream Ghoul.act head: create the partner on the first turn, retrying
	# each turn until an orthogonal cell is free.
	if not partner_spawned:
		_spawn_partner()
	super.act()


func _spawn_partner() -> void:
	if partner_spawned or level == null:
		return
	var candidates: Array[int] = []
	var cx: int = ConstantsData.pos_to_x(pos)
	var cy: int = ConstantsData.pos_to_y(pos)
	for offset: Array in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		var nx: int = cx + int(offset[0])
		var ny: int = cy + int(offset[1])
		if nx < 0 or ny < 0 or nx >= ConstantsData.WIDTH or ny >= ConstantsData.HEIGHT:
			continue
		var cell: int = ConstantsData.xy_to_pos(nx, ny)
		if level.is_passable(cell) and level.find_char_at(cell) == null:
			candidates.append(cell)
	if candidates.is_empty():
		return
	partner_spawned = true
	var child: Ghoul = Ghoul.new()
	child.partner_spawned = true
	child.pos = candidates[randi() % candidates.size()]
	child.level = level
	if state != AIState.SLEEPING:
		child.set_mob_state("wandering")
	level.add_mob(child)
	if TurnManager:
		TurnManager.add_actor(child)


## Upstream Ghoul.die: unless dying to the life link itself or over a chasm,
## a nearby living ghoul catches the body and hosts a GhoulLifeLink instead.
func _try_prevent_death(source: Variant) -> bool:
	if downed:
		return false
	if source is GhoulLifeLink:
		return false
	if level != null and level.has_method("terrain_at") \
			and level.terrain_at(pos) == ConstantsData.Terrain.CHASM:
		return false
	var host: Variant = GhoulLifeLink.search_for_host(self)
	if host == null:
		return false
	times_downed += 1
	downed = true
	hp = 0
	if TurnManager:
		TurnManager.remove_actor(self)
	if level != null:
		level.remove_mob(self)
	var link: GhoulLifeLink = GhoulLifeLink.new()
	link.set_link(self, times_downed * 5)
	host.add_buff(link)
	if MessageLog:
		MessageLog.add("The ghoul crumples, but its body keeps twitching.")
	return true


func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["partner_spawned"] = partner_spawned
	data["times_downed"] = times_downed
	return data


func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	partner_spawned = bool(data.get("partner_spawned", true))
	times_downed = int(data.get("times_downed", 0))
