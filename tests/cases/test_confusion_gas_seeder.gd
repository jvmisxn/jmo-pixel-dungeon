extends RefCounted
## ConfusionGas seeder + effect coverage (SPD parity slice).
##
## Proves the two halves of the ported source path:
##   1. A thrown Potion of Levitation shatters into a ConfusionGas blob at the
##      collision cell (SPD PotionOfLevitation.shatter → Blob.seed(cell,
##      ConfusionGas.class)), and the disorientation waits for the blob tick
##      instead of firing instantly at seed time.
##   2. The ConfusionGas blob applies Vertigo to whatever stands in it — hero and
##      mob alike — mirroring SPD ConfusionGas.evolve()'s
##      Buff.prolong(ch, Vertigo.class, 2).

## Minimal Level stand-in: every cell passable, one char at a fixed cell.
class StubLevel:
	extends RefCounted
	var _char: Char = null
	var _char_cell: int = -1
	func is_passable(_pos: int) -> bool:
		return true
	func find_char_at(cell: int) -> Variant:
		return _char if cell == _char_cell else null

func _center() -> int:
	return ConstantsData.xy_to_pos(16, 16)

func _make_level() -> Level:
	var level := Level.new()
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.build_flag_maps()
	return level

func run(t: Object) -> void:
	_test_levitation_shatter_seeds_confusion_gas(t)
	_test_blob_applies_vertigo(t)

## Thrown Potion of Levitation → confusion gas blob, effect deferred to the tick.
func _test_levitation_shatter_seeds_confusion_gas(t: Object) -> void:
	var level: Level = _make_level()
	var cell: int = _center()
	var victim := Char.new()
	victim.pos = cell
	victim.level = level
	level.add_mob(victim)

	var potion: Potion = Potion.create("levitation")
	potion.shatter(cell, level)

	t.check(_has_blob(level, "confusion_gas"),
			"levitation shatter seeds a confusion_gas blob")
	t.check(not victim.has_buff("Vertigo"),
			"confusion gas waits for the blob tick before applying vertigo")

	level.tick_blobs()
	t.check(victim.has_buff("Vertigo"),
			"confusion gas blob applies vertigo at the collision cell on tick")

	victim.free()

## The blob's own effect path disorients hero and mob alike (SPD affects all).
func _test_blob_applies_vertigo(t: Object) -> void:
	for is_hero: bool in [false, true]:
		var victim := Char.new()
		var cell: int = _center()
		victim.pos = cell
		victim.is_hero = is_hero
		var stub: StubLevel = StubLevel.new()
		stub._char = victim
		stub._char_cell = cell

		var gas := ConfusionGas.new()
		gas.level = stub
		gas.seed(cell, 5.0)
		t.check(not victim.has_buff("Vertigo"),
				"seeding alone does not apply vertigo (hero=%s)" % is_hero)

		gas.tick()
		t.check(victim.has_buff("Vertigo"),
				"confusion gas vertigoes a character standing in it (hero=%s)" % is_hero)
		victim.free()

func _has_blob(level: Level, blob_id: String) -> bool:
	for entry: Dictionary in level.blobs:
		var blob: Variant = entry.get("blob")
		if blob != null and str(blob.get("blob_id")) == blob_id:
			return true
	return false
