extends Node
## Minimal stand-in for GameScene used by test_scene_transition_current_scene.
## Only exposes on_mob_action so TurnManager's scene resolution can be verified
## without instantiating the full GameScene.

var mob_actions: Array[Node] = []

func on_mob_action(actor: Node) -> void:
	mob_actions.append(actor)
