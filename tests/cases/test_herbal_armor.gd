extends RefCounted
## SPD Earthroot.Armor parity for HerbalArmorBuff:
## - no flat armor bonus (old port added +5)
## - per-hit block of `blocking() = (scalingDepth + 5)/2`, drained from an
##   HT-sized pool, returning overflow damage
## - detaches on depletion and on movement
## - pool round-trips through save/load (and migrates legacy `absorb_remaining`)
## - Earthroot plant sizes the pool to the owner's HT

func run(t: Object) -> void:
	# Deterministic depth so blocking() is stable regardless of autoload state.
	if GameManager != null:
		GameManager.depth = 3
	var expected_block: int = (3 + 5) / 2  # = 4

	# --- No flat armor bonus (regression against the old +5 modify_armor) ---
	var probe: HerbalArmorBuff = HerbalArmorBuff.new()
	t.check(probe._blocking() == expected_block, "blocking() = (depth+5)/2")
	t.check(probe.modify_armor(0) == 0, "HerbalArmor no longer grants flat armor")
	probe.free()

	# --- Per-hit block + pool drain via Char.take_damage ---
	var ch: Char = Char.new()
	ch.hp = 30
	ch.hp_max = 30
	ch.ht = 30
	var buff: HerbalArmorBuff = ch.add_buff(HerbalArmorBuff.new()) as HerbalArmorBuff
	buff.apply_pool(ch.ht)
	t.check(buff.pool == 30, "apply_pool sizes the pool to HT")
	t.check(ch.total_shielding() == 0, "HerbalArmor does not report shielding")

	# A hit larger than the block passes the overflow through, drains one block.
	var actual: int = ch.take_damage(10, "test")
	t.check(actual == 10 - expected_block, "Overflow past the per-hit block reaches HP")
	t.check(ch.hp == 30 - (10 - expected_block), "HP drops only by the unblocked amount")
	t.check(buff.pool == 30 - expected_block, "Pool loses exactly one block per hit")
	t.check(ch.has_buff("HerbalArmor"), "Armor persists while the pool remains")

	# A hit smaller than the block is capped to the hit size (block=min(dmg,cap)).
	actual = ch.take_damage(2, "test")
	t.check(actual == 0, "Small hit is fully absorbed")
	t.check(buff.pool == 30 - expected_block - 2, "Small hit drains only its own size")
	ch.free()

	# --- Detaches on move ---
	var mover: Char = Char.new()
	mover.hp = 20
	mover.hp_max = 20
	mover.ht = 20
	var mbuff: HerbalArmorBuff = mover.add_buff(HerbalArmorBuff.new()) as HerbalArmorBuff
	mbuff.apply_pool(mover.ht)
	mover.on_move(5, 6)
	t.check(not mover.has_buff("HerbalArmor"), "Moving detaches the herbal armor")
	mover.free()

	# --- Detaches when the pool is depleted ---
	var drained: Char = Char.new()
	drained.hp = 40
	drained.hp_max = 40
	drained.ht = 40
	var dbuff: HerbalArmorBuff = drained.add_buff(HerbalArmorBuff.new()) as HerbalArmorBuff
	dbuff.apply_pool(expected_block)  # exactly one block left
	actual = drained.take_damage(expected_block + 3, "test")
	t.check(actual == 3, "Depleting hit passes its overflow to HP")
	t.check(not drained.has_buff("HerbalArmor"), "Emptied armor detaches")
	drained.free()

	# --- Serialization round-trip + legacy migration ---
	var s: HerbalArmorBuff = HerbalArmorBuff.new()
	s.apply_pool(17)
	var data: Dictionary = s.serialize()
	t.check(data.get("pool", -1) == 17, "Pool serializes")
	var s2: HerbalArmorBuff = HerbalArmorBuff.new()
	s2.deserialize(data)
	t.check(s2.pool == 17, "Pool restores from save")
	var legacy: HerbalArmorBuff = HerbalArmorBuff.new()
	legacy.deserialize({"absorb_remaining": 9})
	t.check(legacy.pool == 9, "Legacy absorb_remaining migrates into pool")
	s.free()
	s2.free()
	legacy.free()

	# --- Earthroot plant sizes the pool to HT (non-Warden path) ---
	var target: Char = Char.new()
	target.hp = 25
	target.hp_max = 25
	target.ht = 25
	var plant: Earthroot = Earthroot.new()
	plant._do_effect(target, null)
	var applied: HerbalArmorBuff = target.get_buff("HerbalArmor") as HerbalArmorBuff
	t.check(applied != null, "Earthroot applies HerbalArmor to a non-Warden char")
	t.check(applied != null and applied.pool == 25, "Earthroot pool equals owner HT")
	target.free()
