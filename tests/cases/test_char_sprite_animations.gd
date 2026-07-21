extends RefCounted

func run(t: Object) -> void:
	_test_hero_sheet_animation_frames_advance(t)
	_test_rat_sheet_animation_frames_advance(t)
	_test_sprite_shadow_uses_spd_asset(t)


func _test_hero_sheet_animation_frames_advance(t: Object) -> void:
	var sprite := HeroSprite.new()
	t.root.add_child(sprite)
	sprite._ready()
	sprite.setup_for_class(ConstantsData.HeroClass.WARRIOR)

	var texture: AtlasTexture = sprite.get("_sprite").texture as AtlasTexture
	t.check(texture != null and texture.region.position.x == 0.0,
		"HeroSprite starts on the SPD idle frame")

	sprite.move_to(ConstantsData.xy_to_pos(1, 1), 0.2)
	sprite._process(0.06)
	texture = sprite.get("_sprite").texture as AtlasTexture
	t.check(texture != null and int(texture.region.position.x) == HeroSprite.FRAME_WIDTH * 3,
		"HeroSprite movement advances through SPD run frames")

	sprite.free()


func _test_rat_sheet_animation_frames_advance(t: Object) -> void:
	var sprite := MobSprite.new()
	t.root.add_child(sprite)
	sprite._ready()
	sprite.setup_for_mob("rat")

	sprite.place_at(ConstantsData.xy_to_pos(1, 1))
	sprite.play_attack(ConstantsData.xy_to_pos(2, 1), 0.2)
	sprite._process(0.07)
	var texture: AtlasTexture = sprite.get("_sprite").texture as AtlasTexture
	t.check(texture != null and int(texture.region.position.x) == 16 * 3,
		"Rat MobSprite attack advances through SPD attack frames")

	sprite.free()


func _test_sprite_shadow_uses_spd_asset(t: Object) -> void:
	var sprite := HeroSprite.new()
	t.root.add_child(sprite)
	sprite._ready()
	sprite.setup_for_class(ConstantsData.HeroClass.WARRIOR)

	var shadow: Sprite2D = sprite.get("_shadow") as Sprite2D
	t.check(shadow != null and shadow.visible and shadow.texture != null,
		"Character sprites render an SPD shadow texture")

	sprite.free()
