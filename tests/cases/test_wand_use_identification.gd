extends RefCounted
## Covers SPD-style use-based wand identification: the up-front pool only allows
## USES_TO_ID/2 identifying uses, and the remaining pool refills as the hero earns
## XP (Wand.on_hero_gain_exp / Belongings.notify_hero_gain_exp / Hero.earn_xp).

func run(t: Object) -> void:
	_check_pool_stalls_without_xp(t)
	_check_xp_refills_pool(t)
	_check_hero_xp_identifies_wand(t)

func _fresh_wand() -> Wand:
	var wand := Wand.new()
	wand.identified = false
	wand.level_known = false
	wand.cursed_known = false
	return wand

func _check_pool_stalls_without_xp(t: Object) -> void:
	var wand := _fresh_wand()
	# Spend the full up-front pool (USES_TO_ID/2 = 5 uses) with no XP earned.
	for _i: int in range(5):
		wand._use_for_identification()
	t.check(not wand.is_identified(), "wand not identified after only the up-front pool")
	# Further zaps with an empty pool make no ID progress — half the uses remain.
	for _i: int in range(10):
		wand._use_for_identification()
	t.check(not wand.is_identified(), "empty pool cannot identify by spamming zaps")
	t.check(wand._uses_left_to_id == Wand.USES_TO_ID / 2.0,
		"uses-left frozen at half once the available pool is drained")

func _check_xp_refills_pool(t: Object) -> void:
	var wand := _fresh_wand()
	for _i: int in range(5):
		wand._use_for_identification()
	t.check(wand._available_uses_to_id <= 0.0, "available pool drained")
	# A full level's worth of XP refills the whole half-pool (capped).
	wand.on_hero_gain_exp(1.0)
	t.check(is_equal_approx(wand._available_uses_to_id, Wand.USES_TO_ID / 2.0),
		"a full level of XP refills the available pool to the half cap")
	# Never overfills past the cap.
	wand.on_hero_gain_exp(1.0)
	t.check(wand._available_uses_to_id <= Wand.USES_TO_ID / 2.0,
		"available pool never exceeds the half cap")
	# Identified wands stop regenerating.
	wand.identify()
	wand._available_uses_to_id = 0.0
	wand.on_hero_gain_exp(1.0)
	t.check(wand._available_uses_to_id == 0.0, "identified wand does not regenerate pool")

func _check_hero_xp_identifies_wand(t: Object) -> void:
	var hero := Hero.new()
	var wand := _fresh_wand()
	t.check(hero.belongings.add_item(wand), "carried wand added to backpack")
	# Interleave zaps with XP: drain, earn a level of XP to refill, drain again.
	# Over enough cycles the 10 total identifying uses accumulate and the wand IDs.
	for _cycle: int in range(4):
		for _i: int in range(5):
			wand._use_for_identification()
		hero.earn_xp(hero.xp_to_next)  # one level's worth → refills the pool
	t.check(wand.is_identified(),
		"wand identifies by use once XP refills the pool across play")
