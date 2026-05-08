class_name HerbalArmorBuff
extends Buff
## Damage-reduction buff applied by Earthroot plants. Absorbs incoming damage
## up to a maximum threshold, then expires.

const ARMOR_VALUE: int = 5
const BASE_DURATION: float = 20.0
var absorb_remaining: int = 15

func _init() -> void:
	buff_id = "HerbalArmor"
	buff_name = "Herbal Armor"
	is_debuff = false
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.4, 0.3, 0.1)

func modify_armor(armor: int) -> int:
	return armor + ARMOR_VALUE

func on_damage_taken(amount: int, _source: Variant) -> void:
	absorb_remaining -= amount
	if absorb_remaining <= 0 and target:
		target.remove_buff(self)
		if MessageLog:
			MessageLog.add("The herbal armor crumbles away.")

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["absorb_remaining"] = absorb_remaining
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	absorb_remaining = data.get("absorb_remaining", 15)

func description() -> String:
	return "Protected by herbal armor (+%d armor, %d absorb left)." % [ARMOR_VALUE, absorb_remaining]
