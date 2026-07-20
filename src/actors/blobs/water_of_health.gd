class_name WaterOfHealth
extends Blob
## Healing well water, mirroring Shattered Pixel Dungeon's WaterOfHealth
## (a WellWater blob). Seeded on a WELL tile at generation, it holds its single
## cell without spreading or decaying until the hero stands on it. On use it
## fully heals the hero, cures the standard PotionOfHealing ailment set, then
## empties the well (blob cleared + tile -> EMPTY_WELL), exactly as SPD's
## WellWater.use() consumes the well after affectHero() returns true.

## Ailments SPD's PotionOfHealing.cure() strips; WaterOfHealth applies the same
## cleanse when it heals. Only ids that exist as buffs in this port are listed.
const CURABLE_BUFFS: Array[String] = [
	"Poison", "Cripple", "Weakness", "Bleeding", "Blindness",
	"Burning", "Ooze", "Paralysis", "Slow", "Vertigo", "Chill", "Charm",
]

func _init() -> void:
	super._init()
	blob_id = "water_of_health"
	blob_name = "Water of Health"
	# A well holds its shape: it neither spreads to neighbours nor bleeds off
	# volume. It persists untouched until the hero consumes it (SPD WellWater
	# only loses volume through use()).
	spread_rate = 0.0
	decay_rate = 0.0

## Seed a health well on `cell`, routing through Level.add_blob so the blob joins
## the shared blob layer (ticked by advance_blobs, saved by the structured blob
## persistence contract). Mirrors SPD rooms calling Blob.seed(level, cell,
## WaterOfHealth.class) in paint().
static func seed_well(level: Variant, cell: int) -> void:
	if level == null or not level.has_method("add_blob"):
		return
	level.add_blob(WaterOfHealth.new(), cell, 1.0)

## SPD's WellWater only affects the hero; mobs wading through never drain it.
## When the hero is hurt or carries a curable ailment, fully heal + cleanse, then
## consume the well.
func affect_char(ch: Char) -> void:
	if ch == null or not ch.is_hero:
		return
	if ch.hp >= ch.hp_max and not _has_curable_ailment(ch):
		return
	ch.heal(ch.hp_max - ch.hp)
	for buff_id: String in CURABLE_BUFFS:
		if ch.has_buff(buff_id):
			ch.remove_buff_by_id(buff_id)
	if MessageLog:
		MessageLog.add_positive("The well's waters restore you.")
	_consume(ch.pos)

func _has_curable_ailment(ch: Char) -> bool:
	for buff_id: String in CURABLE_BUFFS:
		if ch.has_buff(buff_id):
			return true
	return false

## Empty the used well cell: clear that cell's blob volume (so this blob
## deactivates when the final well is spent) and turn the WELL tile into a spent
## EMPTY_WELL, matching SPD WellWater.use().
func _consume(cell: int) -> void:
	if not ConstantsData.is_valid_pos(cell):
		return
	density[cell] = 0.0
	active_cells.erase(cell)
	if level != null and level.has_method("set_terrain") \
			and ConstantsData.is_valid_pos(cell):
		if level.has_method("terrain_at") \
				and level.terrain_at(cell) == ConstantsData.Terrain.WELL:
			level.set_terrain(cell, ConstantsData.Terrain.EMPTY_WELL)
