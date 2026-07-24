class_name Paralysis
extends Buff
## Completely immobilizes the character via paralysed counter.
## Broken by accumulating enough damage (tracked in ParalysisResist buff).
## Original: FlavourBuff, increments target.paralysed++.
## Damage break uses ParalysisResist buff that persists and decays slowly.

const DURATION: float = 10.0

func _init() -> void:
	buff_id = "Paralysis"
	buff_name = "Paralyzed"
	buff_type = BuffType.NEGATIVE
	announced = true
	duration = DURATION
	time_left = DURATION
	icon_color = Color(1.0, 1.0, 0.0)

func on_attach() -> void:
	if target:
		target.paralysed += 1

func on_detach() -> void:
	if target and target.paralysed > 0:
		target.paralysed -= 1

## Called from Char.take_damage before shields, matching upstream
## Paralysis.processDamage: damage accumulates in a ParalysisResist buff
## so successive hits get progressively better odds of breaking free.
func process_damage(amount: int) -> void:
	if amount <= 0 or target == null:
		return
	var resist: ParalysisResist = target.get_buff("ParalysisResist") as ParalysisResist
	if resist == null:
		resist = target.add_buff(ParalysisResist.new()) as ParalysisResist
	if resist == null:
		return
	resist.damage += amount
	if randi_range(0, resist.damage) >= randi_range(0, maxi(0, target.hp)):
		if MessageLog:
			MessageLog.add_info("%s breaks free from paralysis!" % target.name)
		target.remove_buff(self)

func description() -> String:
	return "Paralyzed! Cannot move or act. Taking damage may break the effect."
