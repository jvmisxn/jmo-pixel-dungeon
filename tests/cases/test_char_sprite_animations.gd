extends RefCounted

func run(t: Object) -> void:
	_test_hero_sheet_animation_frames_advance(t)
	_test_rat_sheet_animation_frames_advance(t)
	_test_rat_idle_jump_uses_sheet_frame(t)
	_test_alert_emote_expires(t)
	_test_damage_number_type_metadata(t)
	_test_sewer_mob_sheet_animation_frames_advance(t)
	_test_sprite_shadow_uses_spd_asset(t)
	_test_zap_animation_keeps_zap_state(t)


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


func _test_rat_idle_jump_uses_sheet_frame(t: Object) -> void:
	var sprite := MobSprite.new()
	t.root.add_child(sprite)
	sprite._ready()
	sprite.setup_for_mob("rat")
	sprite.place_at(ConstantsData.xy_to_pos(1, 1))
	sprite.play_idle_animation()
	var body: Sprite2D = sprite.get("_sprite") as Sprite2D
	var start_y: float = body.position.y

	t.check(is_equal_approx(body.position.y, start_y),
		"Rat idle animation starts without moving the sprite body")
	sprite._process(1.6)
	var texture: AtlasTexture = body.texture as AtlasTexture
	t.check(texture != null and int(texture.region.position.x) == 16,
		"Rat idle animation uses the sprite-sheet jump frame")
	t.check(is_equal_approx(body.position.y, start_y),
		"Rat idle jump uses sheet pixels, not a manual y-offset")

	sprite.free()


func _test_alert_emote_expires(t: Object) -> void:
	var sprite := MobSprite.new()
	t.root.add_child(sprite)
	sprite._ready()
	sprite.setup_for_mob("rat")

	sprite.show_alert(0.05)
	t.check(int(sprite.get("_emo_type")) == CharSprite.EmoType.ALERT,
		"show_alert displays the alert emote")
	sprite._process(0.1)
	t.check(int(sprite.get("_emo_type")) == CharSprite.EmoType.NONE,
		"alert emote expires instead of staying over the mob forever")

	sprite.free()


func _test_damage_number_type_metadata(t: Object) -> void:
	var num := DamageNumber.new()
	t.root.add_child(num)
	num.setup(7, false, "fire")
	t.check(str(num.get("_damage_type")) == "fire",
		"DamageNumber stores the requested damage type for icon drawing")
	var label: Label = num.get("_label") as Label
	t.check(label != null and int(label.position.x) == -12,
		"DamageNumber leaves room for the type icon beside the amount")
	num.free()


func _test_sewer_mob_sheet_animation_frames_advance(t: Object) -> void:
	_check_mob_attack_frame(t, "crab", 16, 8, 0.09, "Crab MobSprite attack advances through SPD attack frames")
	_check_mob_attack_frame(t, "great_crab", 16, 8, 0.09, "Great Crab MobSprite attack advances through SPD attack frames")
	_check_mob_sheet_row(t, "great_crab", 32, "Great Crab MobSprite uses the upstream blue crab sheet row")
	_check_mob_attack_frame(t, "snake", 12, 9, 0.07, "Snake MobSprite attack advances through SPD attack frames")
	_check_mob_attack_frame(t, "slime", 14, 3, 0.07, "Slime MobSprite attack advances through SPD attack frames")
	_check_mob_attack_frame(t, "swarm", 16, 7, 0.07, "Swarm MobSprite attack advances through SPD attack frames")


func _check_mob_attack_frame(t: Object, mob_id: String, frame_width: int, expected_frame: int, delta: float, message: String) -> void:
	var sprite := MobSprite.new()
	t.root.add_child(sprite)
	sprite._ready()
	sprite.setup_for_mob(mob_id)
	sprite.place_at(ConstantsData.xy_to_pos(1, 1))
	sprite.play_attack(ConstantsData.xy_to_pos(2, 1), 0.2)
	sprite._process(delta)
	var texture: AtlasTexture = sprite.get("_sprite").texture as AtlasTexture
	t.check(texture != null and int(texture.region.position.x) == frame_width * expected_frame, message)
	sprite.free()


func _check_mob_sheet_row(t: Object, mob_id: String, expected_y: int, message: String) -> void:
	var sprite := MobSprite.new()
	t.root.add_child(sprite)
	sprite._ready()
	sprite.setup_for_mob(mob_id)
	var texture: AtlasTexture = sprite.get("_sprite").texture as AtlasTexture
	t.check(texture != null and int(texture.region.position.y) == expected_y, message)
	sprite.free()


func _test_sprite_shadow_uses_spd_asset(t: Object) -> void:
	var sprite := HeroSprite.new()
	t.root.add_child(sprite)
	sprite._ready()
	sprite.setup_for_class(ConstantsData.HeroClass.WARRIOR)

	var shadow: Sprite2D = sprite.get("_shadow") as Sprite2D
	t.check(shadow != null and shadow.visible and shadow.texture != null,
		"Character sprites render an SPD shadow texture")
	t.check(shadow.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
		"Character shadows use smooth SPD-style filtering")
	t.check(shadow.scale.x > shadow.scale.y,
		"Character shadows render as a readable oval")

	var body: Sprite2D = sprite.get("_sprite") as Sprite2D
	t.check(body != null and is_equal_approx(body.position.y, 0.0),
		"Character sprites apply the grounded hero offset")
	if shadow != null and body != null:
		var sprite_bottom_y: float = body.position.y + HeroSprite.FRAME_HEIGHT * 0.5
		var shadow_top_y: float = shadow.position.y - (shadow.texture.get_height() * shadow.scale.y) * 0.5
		var shadow_bottom_y: float = shadow.position.y + (shadow.texture.get_height() * shadow.scale.y) * 0.5
		var tile_bottom_y: float = CharSprite.TILE_SIZE * 0.5
		t.check(shadow_top_y <= sprite_bottom_y,
			"Character shadows touch the sprite feet instead of floating below them")
		t.check(sprite_bottom_y >= tile_bottom_y - 1.0,
			"Character feet sit near the bottom of their occupied tile")
		t.check(shadow_bottom_y >= tile_bottom_y - 0.5 and shadow_bottom_y <= tile_bottom_y + 1.5,
			"Character shadows land on the occupied tile baseline")

	sprite.free()


func _test_zap_animation_keeps_zap_state(t: Object) -> void:
	var sprite := HeroSprite.new()
	t.root.add_child(sprite)
	sprite._ready()
	sprite.setup_for_class(ConstantsData.HeroClass.MAGE)
	sprite.place_at(ConstantsData.xy_to_pos(1, 1))

	sprite.play_zap(ConstantsData.xy_to_pos(2, 1), 0.2)
	var texture: AtlasTexture = sprite.get("_sprite").texture as AtlasTexture
	t.check(int(sprite.get("_anim_state")) == CharSprite.AnimState.ZAP,
		"play_zap keeps the sprite in ZAP state instead of overwriting with ATTACK")
	t.check(texture != null and int(texture.region.position.x) == HeroSprite.FRAME_WIDTH * 13,
		"HeroSprite zap starts on the SPD zap frame")

	sprite.free()
