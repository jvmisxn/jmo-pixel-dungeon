extends RefCounted
## Sad Ghost enchanted reward parity: SPD stores the magic roll separately so
## reward previews do not reveal it, then applies it only to the chosen item.

func run(t: Object) -> void:
	_test_enchanted_reward_roll_stays_hidden_until_choice(t)
	_test_unenchanted_reward_roll_leaves_choice_plain(t)
	_test_pending_reward_magic_serializes_separately(t)

func _make_ghost_with_rewards(enchant_rewards: bool) -> SadGhost:
	var ghost: SadGhost = SadGhost.new()
	ghost.reward_weapon = Generator.create_item("sword")
	ghost.reward_armor = Generator.create_item("mail_armor")
	ghost.reward_enchanted = enchant_rewards
	if enchant_rewards:
		ghost.reward_weapon_enchantment = WeaponEnchantment.create("blazing")
		ghost.reward_armor_glyph = ArmorGlyph.create("stone")
	return ghost

func _test_enchanted_reward_roll_stays_hidden_until_choice(t: Object) -> void:
	var ghost: SadGhost = _make_ghost_with_rewards(true)

	t.check(ghost.reward_weapon.enchantment == null,
		"enchanted ghost weapon reward preview stays plain")
	t.check(ghost.reward_armor.glyph == null,
		"enchanted ghost armor reward preview stays unglyphed")

	ghost._apply_enchanted_reward(ghost.reward_weapon)
	t.check(ghost.reward_weapon.enchantment != null,
		"chosen ghost weapon reward receives the stored enchantment")
	t.check(ghost.reward_weapon.enchantment.enchant_id == "blazing",
		"chosen ghost weapon reward receives the exact stored enchantment")
	t.check(ghost.reward_armor.glyph == null,
		"unchosen ghost armor reward stays unglyphed")

	ghost.free()

func _test_unenchanted_reward_roll_leaves_choice_plain(t: Object) -> void:
	var ghost: SadGhost = _make_ghost_with_rewards(false)
	ghost._apply_enchanted_reward(ghost.reward_weapon)

	t.check(ghost.reward_weapon.enchantment == null,
		"plain ghost weapon reward choice stays unenchanted")
	t.check(ghost.reward_armor.glyph == null,
		"plain ghost armor reward choice stays unglyphed")

	ghost.free()

func _test_pending_reward_magic_serializes_separately(t: Object) -> void:
	var ghost: SadGhost = _make_ghost_with_rewards(true)
	var data: Dictionary = ghost.serialize()

	t.check(data.has("reward_weapon_enchantment"),
		"ghost save includes pending reward weapon enchantment")
	t.check(data.has("reward_armor_glyph"),
		"ghost save includes pending reward armor glyph")
	t.check(not (data["reward_weapon"] as Dictionary).has("enchantment"),
		"ghost weapon save does not reveal pending enchantment on the item")
	t.check(not (data["reward_armor"] as Dictionary).has("glyph"),
		"ghost armor save does not reveal pending glyph on the item")

	var restored: SadGhost = SadGhost.new()
	restored.deserialize(data)
	restored._apply_enchanted_reward(restored.reward_armor)

	t.check(restored.reward_armor.glyph != null,
		"restored chosen ghost armor reward receives stored glyph")
	t.check(restored.reward_armor.glyph.glyph_id == "stone",
		"restored chosen ghost armor reward receives the exact stored glyph")
	t.check(restored.reward_weapon.enchantment == null,
		"restored unchosen ghost weapon reward stays unenchanted")

	ghost.free()
	restored.free()
