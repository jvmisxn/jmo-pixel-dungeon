extends RefCounted
## WandOfDisintegration fidelity (audit S14 P1): disintegration ignores physical
## armor, but it is still magical wand damage and must use Char.take_damage().

class _FakeLevel extends RefCounted:
	var target_char: Object = null

	func find_char_at(pos: int) -> Object:
		if target_char != null and int(target_char.get("pos")) == pos:
			return target_char
		return null

	func get_terrain(_pos: int) -> int:
		return ConstantsData.Terrain.EMPTY

	func set_terrain(_pos: int, _terrain: int) -> void:
		pass

class _FixedDisintegration:
	extends Wand.WandOfDisintegration

	var fixed_damage: int = 20

	func roll_zap_damage() -> int:
		return fixed_damage

class _FixedArcaneArmor:
	extends ArcaneArmor

	var fixed_dr: int = 5

	func dr_roll() -> int:
		return fixed_dr

class _DeathTrackedChar:
	extends Char

	var death_count: int = 0

	func _on_death(_source: Variant) -> void:
		death_count += 1

func run(t: Object) -> void:
	_test_barrier_absorbs_disintegration(t)
	_test_arcane_armor_reduces_disintegration(t)
	_test_disintegration_uses_normal_death_path(t)

func _make_target(pos: int = 2) -> _DeathTrackedChar:
	var target := _DeathTrackedChar.new()
	target.name = "DisintegrationTarget"
	target.hp_max = 100
	target.hp = 100
	target.is_alive = true
	target.pos = pos
	return target

func _make_hero_on_floor(target: Char) -> Char:
	var floor := _FakeLevel.new()
	floor.target_char = target
	var hero := Char.new()
	hero.name = "DisintegrationCaster"
	hero.is_alive = true
	hero.pos = 0
	hero.level = floor
	return hero

func _make_wand(damage: int = 20) -> _FixedDisintegration:
	var wand := _FixedDisintegration.new()
	wand.fixed_damage = damage
	wand.level = 0
	return wand

func _zap_target(wand: Object, hero: Char, target: Char) -> void:
	wand.on_zap(hero, [target.pos] as Array[int])

func _test_barrier_absorbs_disintegration(t: Object) -> void:
	var target := _make_target()
	var barrier := Barrier.new()
	barrier.set_shield(12)
	target.add_buff(barrier)
	var hero := _make_hero_on_floor(target)
	var wand := _make_wand(20)

	_zap_target(wand, hero, target)

	t.check(target.hp == 91,
		"Disintegration routes through Barrier before HP")
	t.check(not target.has_buff("Barrier"),
		"Disintegration depletes exhausted Barrier")

	target.free()
	hero.free()

func _test_arcane_armor_reduces_disintegration(t: Object) -> void:
	var target := _make_target()
	target.add_buff(_FixedArcaneArmor.new())
	var hero := _make_hero_on_floor(target)
	var wand := _make_wand(20)

	_zap_target(wand, hero, target)

	t.check(target.hp == 84,
		"Disintegration is reduced by Arcane Armor through take_damage")

	target.free()
	hero.free()

func _test_disintegration_uses_normal_death_path(t: Object) -> void:
	var target := _make_target()
	target.hp = 10
	var hero := _make_hero_on_floor(target)
	var wand := _make_wand(20)

	_zap_target(wand, hero, target)

	t.check(not target.is_alive,
		"Disintegration kills through the normal Char death path")
	t.check(target.death_count == 1,
		"Disintegration death handling runs exactly once")

	target.free()
	hero.free()
