class_name SoulMark
extends Buff
## Applied to enemies by the Warlock's Soul Mark passive.
## When this enemy dies to melee, the Warlock heals and satisfies hunger.

func _init() -> void:
	buff_id = "SoulMark"
	buff_name = "Soul Marked"
	buff_type = BuffType.NEGATIVE
	duration = 10.0
	time_left = 10.0
	icon_color = Color(0.5, 0.1, 0.7)

## Called when the marked enemy dies. Source is the killer.
func on_marked_death(source: Variant) -> void:
	if source == null or not (source is Node and source.get("is_hero") == true):
		return
	var hero: Node = source
	if hero.hero_subclass != ConstantsData.HeroSubclass.WARLOCK:
		return
	# Heal 10% of the enemy's max HP
	if target:
		@warning_ignore("integer_division")
		var heal_amount: int = maxi(1, target.hp_max / 10)
		hero.heal(heal_amount)
		if MessageLog:
			MessageLog.add_positive("Soul Mark heals you for %d!" % heal_amount)
	# Satisfy some hunger
	var hunger_buff: Node = hero.get_buff("Hunger")
	if hunger_buff and hunger_buff.has_method("satisfy"):
		hunger_buff.satisfy(50.0)

func description() -> String:
	return "Soul marked! Dealing damage heals the warlock."
