extends RefCounted
## Descend-sting gating parity against Shattered Pixel Dungeon's
## `GameScene.create`: Assets.Sounds.DESCEND plays only on first arrival at a
## new deepest floor (fresh level entered via DESCEND or FALL). Ascending,
## backtracking to an already-visited floor, and continuing a saved game play
## no stairs sound.

func run(t: Object) -> void:
	t.check(LoadingScene.should_play_descend_sfx("descend", false, false),
		"descending to a freshly generated floor plays the sting")
	t.check(LoadingScene.should_play_descend_sfx("fall", false, false),
		"falling onto a freshly generated floor plays the sting")
	t.check(not LoadingScene.should_play_descend_sfx("ascend", false, false),
		"ascending never plays the descend sting")
	t.check(not LoadingScene.should_play_descend_sfx("descend", true, false),
		"backtracking to a cached floor is silent")
	t.check(not LoadingScene.should_play_descend_sfx("fall", true, false),
		"falling onto an already-visited floor is silent")
	t.check(not LoadingScene.should_play_descend_sfx("descend", false, true),
		"continuing a saved game is silent")
