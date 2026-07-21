extends RefCounted

class FakeHero:
	extends Node

	signal buff_added(buff: Node)
	signal buff_removed(buff: Node)

	var is_alive: bool = true
	var hp: int = 20
	var hp_max: int = 20
	var shielding: int = 0
	var xp: int = 0
	var xp_to_next: int = 10
	var hero_level: int = 1
	var str_val: int = 10
	var hero_class: int = ConstantsData.HeroClass.WARRIOR
	var hero_name: String = ""
	var hero_slot_index: int = 0
	var belongings: RefCounted = null
	var buffs: Array[Node] = []

	func get_buffs() -> Array[Node]:
		return buffs

class DesktopHud:
	extends HUD

	var fake_canvas_size: Vector2 = Vector2(1280, 720)

	class StubComponent:
		extends Control

		func update_all() -> void:
			pass

		func refresh() -> void:
			pass

		func set_compact_mode(_is_compact: bool) -> void:
			pass

		func set_available_width(_available_width: float) -> void:
			pass

		func set_action_controls_enabled(_is_enabled: bool) -> void:
			pass

	func _instantiate_script(path: String) -> Variant:
		if path == "res://src/ui/toolbar.gd":
			var toolbar := Toolbar.new()
			toolbar._ready()
			return toolbar
		return StubComponent.new()

	func _get_canvas_viewport_size() -> Vector2:
		return fake_canvas_size

func _atlas_region_has_pixels(path: String, region: Rect2) -> bool:
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		return false
	var image: Image = texture.get_image()
	if image == null:
		return false
	var rect: Rect2i = Rect2i(region)
	for y: int in range(rect.position.y, rect.position.y + rect.size.y):
		for x: int in range(rect.position.x, rect.position.x + rect.size.x):
			if image.get_pixel(x, y).a > 0.0:
				return true
	return false

func run(t: Object) -> void:
	var previous_hero: Node = GameManager.hero
	var previous_heroes: Array[Node] = GameManager.heroes.duplicate()
	var previous_local_hero_index: int = GameManager.local_hero_index

	var hero := FakeHero.new()
	GameManager.hero = hero
	GameManager.heroes = [hero]
	GameManager.local_hero_index = 0

	var hud := DesktopHud.new()
	hud._vp_size = Vector2(1280, 720)
	hud._build_layout()
	hud.update_all()
	hud._apply_viewport_size(Vector2(1280, 720))

	t.check(
		not hud._is_mobile_layout(),
		"desktop buff HUD test uses the desktop layout breakpoint"
	)

	var layout_root: Control = hud.get_node_or_null("HUDRoot") as Control
	t.check(layout_root != null, "desktop HUD builds its layout root")
	if layout_root == null:
		hud.free()
		hero.free()
		GameManager.hero = previous_hero
		GameManager.heroes = previous_heroes
		GameManager.local_hero_index = previous_local_hero_index
		return
	var desktop_buffs_row: HFlowContainer = layout_root.get_node_or_null("MobileBuffsRow") as HFlowContainer
	var socket_texture: AtlasTexture = null
	if hud._status_avatar_socket != null:
		socket_texture = hud._status_avatar_socket.texture as AtlasTexture
	var socket_atlas: Texture2D = null
	if socket_texture != null:
		socket_atlas = socket_texture.atlas as Texture2D
	var avatar_texture: AtlasTexture = null
	if hud._status_avatar != null:
		avatar_texture = hud._status_avatar.texture as AtlasTexture
	var avatar_atlas: Texture2D = null
	if avatar_texture != null:
		avatar_atlas = avatar_texture.atlas as Texture2D
	t.check(
		socket_atlas != null
				and socket_atlas.resource_path == "res://assets/spd/interfaces/status_pane.png"
				and socket_texture.region == Rect2(0, 0, 30, 36),
		"desktop HUD status pane uses the unscaled SPD avatar socket"
	)
	t.check(
		hud._status_avatar != null
				and avatar_atlas != null
				and avatar_atlas.resource_path == "res://assets/spd/sprites/avatars.png"
				and avatar_texture.region == Rect2(0, 0, 24, 32),
		"desktop HUD status pane uses the SPD 24x32 hero avatar atlas frame"
	)
	t.check(
		desktop_buffs_row != null and not desktop_buffs_row.visible,
		"desktop buff row starts hidden when the local hero has no active buffs"
	)

	var poison := Poison.create(5.0)
	hero.buffs.append(poison)
	hero.buff_added.emit(poison)
	var poison_region: Rect2 = BuffIcon.icon_region_for_buff_id("Poison")
	var invisible_region: Rect2 = BuffIcon.icon_region_for_buff_id("Invisibility")
	t.check(
		poison_region == Rect2(48, 0, 16, 16)
				and _atlas_region_has_pixels("res://assets/spd/interfaces/large_buffs.png", poison_region),
		"Poison uses the SPD large buff atlas icon"
	)
	t.check(
		invisible_region == Rect2(192, 0, 16, 16)
				and _atlas_region_has_pixels("res://assets/spd/interfaces/large_buffs.png", invisible_region),
		"Invisibility uses the SPD large buff atlas icon"
	)
	t.check(
		BuffIcon.BUFFS_PATH == "res://assets/spd/interfaces/large_buffs.png",
		"BuffIcon uses SPD's 16x16 large buff sheet"
	)
	t.check(
		desktop_buffs_row != null
				and desktop_buffs_row.visible
				and desktop_buffs_row.get_child_count() == 1
				and (desktop_buffs_row.get_child(0) as BuffIcon) != null,
		"desktop HUD renders local hero buffs as a visible BuffIcon row"
	)
	t.check(
		desktop_buffs_row != null
				and (desktop_buffs_row.get_child(0) as BuffIcon).buff_ref == poison,
		"desktop HUD BuffIcon tracks the live Poison buff reference"
	)

	hero.buffs.erase(poison)
	hero.buff_removed.emit(poison)
	t.check(
		desktop_buffs_row != null
				and not desktop_buffs_row.visible
				and desktop_buffs_row.get_child_count() == 0,
		"desktop HUD refreshes buff icons immediately when the local hero loses a buff"
	)

	hud.free()
	poison.free()
	hero.free()
	GameManager.hero = previous_hero
	GameManager.heroes = previous_heroes
	GameManager.local_hero_index = previous_local_hero_index
