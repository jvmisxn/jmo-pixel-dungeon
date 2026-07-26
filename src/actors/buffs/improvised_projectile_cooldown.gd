class_name ImprovisedProjectileCooldown
extends Buff
## Warrior Improvised Projectiles cooldown (upstream
## Talent.ImprovisedProjectileCooldown, a 50-turn FlavourBuff): after blinding
## an enemy with a thrown non-weapon item, the talent cannot trigger again
## until this buff expires.

const DURATION := 50.0

func _init() -> void:
	buff_id = "ImprovisedProjectileCooldown"
	buff_name = "Improvised Projectiles Cooldown"
	buff_type = BuffType.NEUTRAL
	duration = DURATION
	icon_color = Color(0.55, 0.55, 0.55)

func description() -> String:
	return "You have recently blinded an enemy with an improvised projectile, and need a moment before you can line up another such throw."
