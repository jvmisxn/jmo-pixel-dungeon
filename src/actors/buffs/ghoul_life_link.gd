class_name GhoulLifeLink
extends Buff
## Upstream Ghoul.GhoulLifeLink: attached to a living "host" ghoul when a
## partner ghoul is downed. Counts down 5*times_downed turns on the host's
## timeline, then revives the downed ghoul at HT/10 HP. If the host loses
## sight of the body (no LOS and distance >= 4) or dies, the link transfers
## to another nearby ghoul, or the downed ghoul dies for real.
##
## Port adaptations: the downed ghoul is removed from level.mobs/TurnManager
## while downed (upstream removes it from Actor + mobs too), so it is not
## targetable and does not block movement; the crumpled-body sprite is not
## rendered while downed. Each link instance gets a unique buff_id so two
## downed ghouls can link to one host without Char.add_buff merging them
## (upstream uses Buff.append for the same reason).

static var _next_link_serial: int = 0

var ghoul: Variant = null
var turns_to_revive: int = 0
## Set when the link has resolved (revive, transfer, or real death) so
## on_detach does not run the re-host fallback.
var _completed: bool = false

func _init() -> void:
	buff_name = "Ghoul Life Link"
	buff_type = BuffType.NEUTRAL
	show_in_ui = false
	duration = -1.0
	_next_link_serial += 1
	buff_id = "GhoulLifeLink:%d" % _next_link_serial


func set_link(downed_ghoul: Variant, turns: int) -> void:
	ghoul = downed_ghoul
	turns_to_revive = turns


func on_attach() -> void:
	if target != null and target.has_signal("died") and not target.died.is_connected(_on_host_died):
		target.died.connect(_on_host_died)


func on_detach() -> void:
	if target != null and target.has_signal("died") and target.died.is_connected(_on_host_died):
		target.died.disconnect(_on_host_died)
	if not _completed:
		_completed = true
		_transfer_or_die()


func is_expired() -> bool:
	return _completed


func description() -> String:
	return "This ghoul is sustaining a downed partner, which will get back up in %d turns unless the link is broken." % maxi(turns_to_revive, 0)


func on_turn() -> void:
	if _completed:
		return
	if ghoul == null or not (ghoul is Object) or not is_instance_valid(ghoul):
		_completed = true
		return
	var host: Variant = target
	if host == null:
		return
	# Upstream: detach (-> transfer) when the host cannot see the body and is
	# 4+ tiles away.
	var level_ref: Variant = _level()
	if level_ref != null and _chebyshev(host.pos, ghoul.pos) >= 4:
		var sees: bool = false
		if level_ref.has_method("has_los"):
			sees = level_ref.has_los(host.pos, ghoul.pos)
		if not sees:
			_completed = true
			_transfer_or_die()
			return
	turns_to_revive -= 1
	if turns_to_revive <= 0:
		_try_revive()


func _on_host_died() -> void:
	if _completed:
		return
	_completed = true
	_transfer_or_die()


func _try_revive() -> void:
	var level_ref: Variant = _level()
	if level_ref == null:
		return
	var revive_pos: int = ghoul.pos
	if level_ref.has_method("find_char_at") and level_ref.find_char_at(revive_pos) != null:
		revive_pos = _free_neighbour(level_ref, ghoul.pos)
		if revive_pos < 0:
			return  # upstream: wait a turn until a cell frees up
	ghoul.pos = revive_pos
	ghoul.hp = maxi(1, int(round(float(ghoul.hp_max) / 10.0)))
	ghoul.downed = false
	ghoul.level = level_ref
	level_ref.add_mob(ghoul)
	if TurnManager:
		TurnManager.add_actor(ghoul)
	if ghoul.has_method("set_mob_state"):
		ghoul.set_mob_state("wandering")
	if MessageLog:
		MessageLog.add_warning("The ghoul gets back up!")
	_completed = true


## Move the link to another nearby ghoul, or kill the downed ghoul for real
## (upstream GhoulLifeLink.detach).
func _transfer_or_die() -> void:
	if ghoul == null or not (ghoul is Object) or not is_instance_valid(ghoul):
		return
	if not ghoul.get("downed"):
		return
	var new_host: Variant = search_for_host(ghoul, target)
	if new_host != null:
		var link: GhoulLifeLink = GhoulLifeLink.new()
		link.set_link(ghoul, turns_to_revive)
		new_host.add_buff(link)
	else:
		ghoul.die(self)


## Find a living ghoul (other than `dying` and `exclude`) that can see the
## body or is within 4 tiles of it (upstream GhoulLifeLink.searchForHost).
static func search_for_host(dying: Variant, exclude: Variant = null) -> Variant:
	var level_ref: Variant = dying.get("level")
	if level_ref == null:
		return null
	for m: Variant in level_ref.mobs:
		if m == dying or m == exclude or not (m is Object) or not is_instance_valid(m):
			continue
		if m.get("mob_id") != "ghoul" or not m.is_alive or m.get("downed"):
			continue
		if m.get("is_ally") != dying.get("is_ally"):
			continue
		if _chebyshev(m.pos, dying.pos) < 4:
			return m
		if level_ref.has_method("has_los") and level_ref.has_los(m.pos, dying.pos):
			return m
	return null


static func _chebyshev(a: int, b: int) -> int:
	var dx: int = absi(ConstantsData.pos_to_x(a) - ConstantsData.pos_to_x(b))
	var dy: int = absi(ConstantsData.pos_to_y(a) - ConstantsData.pos_to_y(b))
	return maxi(dx, dy)


func _level() -> Variant:
	if ghoul != null and ghoul is Object and is_instance_valid(ghoul) and ghoul.get("level") != null:
		return ghoul.level
	if target != null:
		return target.get("level")
	return null


static func _free_neighbour(level_ref: Variant, center: int) -> int:
	var cx: int = ConstantsData.pos_to_x(center)
	var cy: int = ConstantsData.pos_to_y(center)
	var candidates: Array[int] = []
	for dy: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = cx + dx
			var ny: int = cy + dy
			if nx < 0 or ny < 0 or nx >= ConstantsData.WIDTH or ny >= ConstantsData.HEIGHT:
				continue
			var cell: int = ConstantsData.xy_to_pos(nx, ny)
			if level_ref.is_passable(cell) and level_ref.find_char_at(cell) == null:
				candidates.append(cell)
	if candidates.is_empty():
		return -1
	return candidates[randi() % candidates.size()]


func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["turns_to_revive"] = turns_to_revive
	if ghoul != null and ghoul is Object and is_instance_valid(ghoul) and ghoul.has_method("serialize"):
		data["ghoul_data"] = ghoul.serialize()
	return data


func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	turns_to_revive = int(data.get("turns_to_revive", 0))
	var ghoul_data: Variant = data.get("ghoul_data")
	if ghoul_data is Dictionary:
		var script_path: String = str((ghoul_data as Dictionary).get("_class", ""))
		if not script_path.is_empty() and ResourceLoader.exists(script_path):
			var ghoul_script: GDScript = load(script_path)
			if ghoul_script != null:
				ghoul = ghoul_script.new()
				ghoul.deserialize(ghoul_data)
				ghoul.downed = true
				ghoul.is_alive = true
