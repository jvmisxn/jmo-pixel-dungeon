extends RefCounted
## Ring of Wealth must actually multiply collected gold piles. Covers:
##   - no ring leaves a gold pile's quantity untouched
##   - an equipped ring scales the pile by 1.2^bonus (rounded, floor of 1)
##   - a higher upgrade level yields a larger multiplier
##   - unequipping the ring removes the bonus

const HERO_SCRIPT: String = "res://src/actors/hero/hero.gd"
const GOLD_SCRIPT: String = "res://src/items/gold.gd"

const PILE: int = 100

func run(t: Object) -> void:
	_check_no_ring(t)
	_check_ring_scales(t)
	_check_unequip_clears(t)
	_check_pickup_uses_scaled_gold(t)

func _make_hero() -> Object:
	var hero_script: GDScript = load(HERO_SCRIPT) as GDScript
	var hero: Object = hero_script.new()
	hero.hp = 20
	hero.hp_max = 20
	hero.ht = 20
	return hero

func _make_gold(amount: int) -> Object:
	var gold_script: GDScript = load(GOLD_SCRIPT) as GDScript
	return gold_script.new(amount)

func _make_wealth_ring(level: int) -> Object:
	var ring: Object = Generator.create_item("ring_of_wealth")
	ring.level = level
	ring.cursed = false
	return ring

func _expected(amount: int, bonus: int) -> int:
	if bonus == 0:
		return amount
	return maxi(1, int(round(float(amount) * pow(1.2, float(bonus)))))

func _check_no_ring(t: Object) -> void:
	var hero: Object = _make_hero()
	var gold: Object = _make_gold(PILE)
	t.check(gold.wealth_adjusted_quantity(hero) == PILE, "no ring leaves gold unchanged")
	t.check(gold.wealth_adjusted_quantity(null) == PILE, "null hero leaves gold unchanged")
	hero.free()

func _check_ring_scales(t: Object) -> void:
	var hero: Object = _make_hero()
	hero.belongings.equip_ring(_make_wealth_ring(1), true)
	var gold: Object = _make_gold(PILE)
	var lvl1: int = gold.wealth_adjusted_quantity(hero)
	t.check(lvl1 == _expected(PILE, 1), "level-1 wealth ring scales gold by 1.2x")
	t.check(lvl1 > PILE, "wealth ring increases the collected pile")
	hero.free()

	var hero2: Object = _make_hero()
	hero2.belongings.equip_ring(_make_wealth_ring(3), true)
	var gold2: Object = _make_gold(PILE)
	var lvl3: int = gold2.wealth_adjusted_quantity(hero2)
	t.check(lvl3 == _expected(PILE, 3), "level-3 wealth ring scales gold by 1.2^3")
	t.check(lvl3 > lvl1, "higher ring level yields a larger multiplier")
	hero2.free()

func _check_unequip_clears(t: Object) -> void:
	var hero: Object = _make_hero()
	hero.belongings.equip_ring(_make_wealth_ring(2), true)
	hero.belongings.unequip("ring_left")
	var gold: Object = _make_gold(PILE)
	t.check(gold.wealth_adjusted_quantity(hero) == PILE, "unequip removes the wealth bonus")
	hero.free()

func _check_pickup_uses_scaled_gold(t: Object) -> void:
	var previous_gold: int = GameManager.gold if GameManager else 0
	var previous_stats: Dictionary = GameManager.stats.duplicate(true) if GameManager else {}
	var hero: Object = _make_hero()
	hero.belongings.equip_ring(_make_wealth_ring(2), true)
	var gold: Object = _make_gold(PILE)
	var expected: int = gold.wealth_adjusted_quantity(hero)
	if GameManager:
		GameManager.gold = 0
		GameManager.stats["gold_collected"] = 0
	gold.on_pickup(hero)
	if GameManager:
		t.check(GameManager.gold == expected, "gold pickup collects the wealth-scaled amount")
		t.check(GameManager.stats.get("gold_collected", 0) == expected, "wealth-scaled pickup updates gold stats")
		GameManager.gold = previous_gold
		GameManager.stats = previous_stats
	hero.free()
