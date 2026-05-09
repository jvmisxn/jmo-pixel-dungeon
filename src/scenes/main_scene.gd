class_name MainScene
extends Node2D
## Entry point scene. Launches the title screen (Phase 5 UI).
## Can also be used to directly start a game for testing via _start_new_game().

var _game_scene: GameScene = null

func _ready() -> void:
	# Launch the title screen via SceneManager
	var title_script: GDScript = preload("res://src/scenes/title_scene.gd")
	SceneManager.go_to(title_script, "TitleScene")

func _start_new_game() -> void:
	# Initialize game state
	GameManager.new_game(ConstantsData.HeroClass.WARRIOR)

	# Create hero
	var hero: Hero = Hero.new()
	hero.init_class(GameManager.hero_class)
	hero.give_starting_items()
	hero.pos = -1  # Will be set by level load
	GameManager.hero = hero
	GameManager.heroes = [hero]

	# Generate the first level
	var level: Level = LevelFactory.create_for_depth(GameManager.depth)
	GameManager.current_level = level

	# Place hero at entrance
	hero.pos = level.entrance

	# Register hero with turn manager (use activate() so active flag is set)
	TurnManager.clear_actors()
	hero.active = false
	hero.activate()

	# Register mobs (use activate() so deactivate on death works properly)
	for mob: Variant in level.mobs:
		if mob is Node:
			mob.active = false
			mob.activate()

	# Create and set up game scene
	_game_scene = GameScene.new()
	_game_scene.name = "GameScene"
	add_child(_game_scene)

	# Load level visuals
	var region: int = ConstantsData.region_for_depth(GameManager.depth)
	_game_scene.load_level(level, region)

	# Start the turn loop
	TurnManager.process_until_hero()
