extends RefCounted
## Buff description content pass (upstream actors.properties /
## items.properties text): the previously desc-less player-visible buffs now
## return upstream SPD descriptions with live stat interpolation.


func run(t: Object) -> void:
	# --- AdrenalineSurge: strength boost value interpolated ---
	var surge := AdrenalineSurge.create(2)
	t.check(surge.description().contains("Strength boost: +2."),
		"AdrenalineSurge desc shows the STR bonus")
	t.check(surge.description().contains("surge of great might"),
		"AdrenalineSurge desc uses upstream text")

	# --- Chill: turns left and speed reduction from speed_factor() ---
	var chill := Chill.new()
	chill.set_level(4.0)
	t.check(chill.description().contains("Speed is reduced by: 40%"),
		"Chill desc reports 10% slow per turn remaining")
	chill.set_level(9.0)
	t.check(chill.description().contains("Speed is reduced by: 50%"),
		"Chill desc caps the reported slow at 50%")

	# --- Hunger: intro line switches between hungry and starving ---
	var hunger := Hunger.new()
	hunger.hunger_value = Hunger.HUNGRY_THRESHOLD
	t.check(hunger.description().contains("stomach calling out for food"),
		"Hunger desc uses the hungry intro before starving")
	hunger.hunger_value = Hunger.STARVING_THRESHOLD
	t.check(hunger.description().contains("so hungry it hurts"),
		"Hunger desc switches to the starving intro")
	t.check(hunger.description().contains("Rationing is important!"),
		"Hunger desc keeps the shared rationing body text")

	# --- Invisibility / Slow / Weakness: upstream body text present ---
	var invis := Invisibility.new()
	t.check(invis.description().contains("impossible to see"),
		"Invisibility desc uses upstream text")
	var slow := Slow.new()
	t.check(slow.description().contains("twice the amount of time"),
		"Slow desc uses upstream text")
	var weak := Weakness.new()
	t.check(weak.description().contains("33% reduced damage"),
		"Weakness desc states the upstream damage penalty")

	# --- WarriorShield: active vs cooldown variants ---
	var shield := WarriorShield.new()
	shield.shield_amount = 5
	shield.cooldown = 150
	var active_desc: String = shield.description()
	t.check(active_desc.contains("Shield remaining: 5."),
		"WarriorShield active desc shows shield remaining")
	t.check(active_desc.contains("Current Cooldown: 150."),
		"WarriorShield active desc shows the cooldown")
	shield.shield_amount = 0
	shield.cooldown = 42
	t.check(shield.description().contains("Turns Remaining: 42."),
		"WarriorShield cooldown desc shows turns remaining")

	# --- Every non-internal buff now returns a non-empty description ---
	var internal_ids := ["DelayedPit", "GrimTracker", "KineticTracker", "LethalMomentumTracker",
		"ParalysisResist", "ProtectiveShadowsTracker", "Regeneration",
		"WandPreservationCounter", "RejuvenatingStepsFurrow"]
	var dir := DirAccess.open("res://src/actors/buffs")
	t.check(dir != null, "buffs directory opens")
	if dir != null:
		for file_name: String in dir.get_files():
			if not file_name.ends_with(".gd") or file_name == "buff.gd":
				continue
			var script: GDScript = load("res://src/actors/buffs/" + file_name)
			if script == null or not script.can_instantiate():
				continue
			var buff: Variant = script.new()
			if not (buff is Buff):
				continue
			var b: Buff = buff
			if b.buff_id in internal_ids:
				continue
			t.check(not b.description().is_empty(),
				"%s has a description" % file_name)
