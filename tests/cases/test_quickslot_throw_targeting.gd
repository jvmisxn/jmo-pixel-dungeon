extends RefCounted

## Quickslotted throwables must route to auto-aim throw targeting instead of
## the no-op use_item path (upstream QuickSlotButton.useTargeting): base
## Item.execute is a no-op, so before this routing a quickslot tap on a dart
## or the spirit bow burned a turn doing nothing.


func run(t: Object) -> void:
	var dart: MissileWeapon = MissileWeapon.create("dart")
	var trident: MissileWeapon = MissileWeapon.create("trident")
	var bow: SpiritBow = SpiritBow.new()
	var wand: Wand = Wand.create("wand_of_magic_missile")
	var potion: Potion = Potion.create("healing")

	t.check(
		HUD.quickslot_uses_throw_targeting(dart),
		"missile weapons use throw targeting from the quickslot"
	)
	t.check(
		HUD.quickslot_uses_throw_targeting(bow),
		"spirit bow uses throw targeting from the quickslot"
	)
	t.check(
		not HUD.quickslot_uses_throw_targeting(wand),
		"wands keep their own zap quickslot branch"
	)
	t.check(
		not HUD.quickslot_uses_throw_targeting(potion),
		"non-throwable items fall through to use_item"
	)
	t.check(
		not HUD.quickslot_uses_throw_targeting(null),
		"null quickslot item never routes to throw targeting"
	)

	t.check(
		HUD.quickslot_throw_range(dart) == 6,
		"tier-1 missile throw range is 4 + tier * 2 = 6 (matches WndItem)"
	)
	t.check(
		HUD.quickslot_throw_range(trident) == 14,
		"tier-5 missile throw range is 4 + tier * 2 = 14 (matches WndItem)"
	)
	t.check(
		HUD.quickslot_throw_range(bow) == 8,
		"spirit bow shoot range is 8 (matches WndItem shoot)"
	)
