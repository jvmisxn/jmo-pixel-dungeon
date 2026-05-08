class_name Food
extends Item
## Base food class. Stackable consumables that satisfy hunger and may heal or
## apply effects. All food items are created via the static factory `create()`.

# --- Properties ---
## Amount of hunger this food satisfies (out of MAX_HUNGER = 450).
var hunger_satisfy: float = 0.0
## HP healed on consumption.
var heal_amount: int = 0
## If true, apply a random effect instead of a fixed one (mystery meat).
var random_effect: bool = false

func _init() -> void:
	category = ConstantsData.ItemCategory.FOOD
	stackable = true
	default_action = "EAT"
	identified = true
	cursed_known = true
	icon_color = Color(0.85, 0.55, 0.25)

func is_upgradeable() -> bool:
	return false

# ---------------------------------------------------------------------------
# Execution
# ---------------------------------------------------------------------------

## Default action: eat the food.
func execute(hero: Char) -> void:
	eat(hero)

## Consume the food, satisfying hunger, healing, and applying effects.
func eat(hero: Char) -> void:
	if hero == null:
		return

	# Satisfy hunger
	var hunger_buff: Variant = hero.get_buff("Hunger") if hero.has_method("get_buff") else null
	if hunger_buff != null and hunger_buff.has_method("satisfy"):
		if hunger_satisfy >= ConstantsData.MAX_HUNGER:
			hunger_buff.fully_satisfy()
		else:
			hunger_buff.satisfy(hunger_satisfy)

	# Heal
	if heal_amount > 0 and hero.has_method("heal"):
		hero.heal(heal_amount)

	# Random effect (mystery meat)
	if random_effect:
		_apply_random_effect(hero)

	# Frozen carpaccio grants a random positive buff
	if _is_carpaccio():
		_apply_carpaccio_buff(hero)

	# Message
	if MessageLog:
		MessageLog.add("You eat the %s." % item_name)

	# Statistics
	if GameManager:
		GameManager.record_stat("food_eaten")
	if EventBus:
		EventBus.item_used.emit(item_name)

	# Consume one from stack
	_consume_one(hero)

## Apply a random effect for mystery meat.
func _apply_random_effect(hero: Char) -> void:
	var roll: int = randi_range(0, 3)
	match roll:
		0:
			# Heal a moderate amount
			if hero.has_method("heal"):
				hero.heal(randi_range(5, 10))
			if MessageLog:
				MessageLog.add_positive("That tasted alright!")
		1:
			# Poison
			if hero.has_method("add_buff"):
				var poison: Poison = Poison.new()
				poison.set_duration(5.0)
				hero.add_buff(poison)
			if MessageLog:
				MessageLog.add_negative("That meat was not fresh at all!")
		2:
			# Burn
			if hero.has_method("add_buff"):
				var burn: Burning = Burning.new()
				burn.set_duration(4.0)
				hero.add_buff(burn)
			if MessageLog:
				MessageLog.add_negative("It burns your throat!")
		3:
			# Paralyze
			if hero.has_method("add_buff"):
				var para: Paralysis = Paralysis.new()
				para.set_duration(5.0)
				hero.add_buff(para)
			if MessageLog:
				MessageLog.add_negative("You can't move!")

## Apply a random positive buff for frozen carpaccio.
func _apply_carpaccio_buff(hero: Char) -> void:
	if hero == null or not hero.has_method("add_buff"):
		return
	var roll: int = randi_range(0, 4)
	match roll:
		0:
			var inv: Invisibility = Invisibility.new()
			inv.set_duration(10.0)
			hero.add_buff(inv)
			if MessageLog:
				MessageLog.add_positive("You feel your body fade from sight.")
		1:
			var haste_buff: Haste = Haste.new()
			haste_buff.set_duration(10.0)
			hero.add_buff(haste_buff)
			if MessageLog:
				MessageLog.add_positive("You feel invigorated!")
		2:
			var mind: MindVision = MindVision.new()
			mind.set_duration(10.0)
			hero.add_buff(mind)
			if MessageLog:
				MessageLog.add_positive("You can sense the minds of others!")
		3:
			if hero.has_method("heal"):
				hero.heal(randi_range(8, 15))
			if MessageLog:
				MessageLog.add_positive("Warmth fills your body.")
		4:
			var levi: Levitation = Levitation.new()
			levi.set_duration(10.0)
			hero.add_buff(levi)
			if MessageLog:
				MessageLog.add_positive("You feel weightless!")

## Remove one quantity from the stack, removing the item if depleted.
func _consume_one(hero: Char) -> void:
	quantity -= 1
	if quantity <= 0:
		if hero != null and hero.has_method("get") and hero.get("belongings") != null:
			hero.belongings.remove_item(self)

# ---------------------------------------------------------------------------
# Value
# ---------------------------------------------------------------------------

func value() -> int:
	match item_id:
		"overpriced_ration":
			return 30 * quantity
		"meat_pie":
			return 25 * quantity
		_:
			return 10 * quantity

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["_class"] = "Food"
	data["hunger_satisfy"] = hunger_satisfy
	data["heal_amount"] = heal_amount
	data["random_effect"] = random_effect
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	hunger_satisfy = data.get("hunger_satisfy", 0.0)
	heal_amount = data.get("heal_amount", 0)
	random_effect = data.get("random_effect", false)

# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

## Create a food item by ID.
static func create(food_id: String) -> Food:
	var food: Food = Food.new()
	food.item_id = food_id

	match food_id:
		"ration":
			food.item_name = "Ration of Food"
			food.description = "Nothing fancy, but it will fill you up."
			food.hunger_satisfy = ConstantsData.MAX_HUNGER
			food.heal_amount = 1
			food.icon_color = Color(0.85, 0.55, 0.25)

		"pasty":
			food.item_name = "Pasty"
			food.description = "A warm, flaky pastry. Filling and slightly restorative."
			food.hunger_satisfy = ConstantsData.MAX_HUNGER
			food.heal_amount = 10
			food.icon_color = Color(0.9, 0.75, 0.45)

		"mystery_meat":
			food.item_name = "Mystery Meat"
			food.description = "Charred meat of an unknown creature. Eating it is risky."
			# Original: Hunger.HUNGRY/2 = 300/2 = 150 (not MAX_HUNGER*0.5 = 225)
			food.hunger_satisfy = 150.0
			food.heal_amount = 0
			food.random_effect = true
			food.icon_color = Color(0.7, 0.3, 0.3)

		"overpriced_ration":
			food.item_name = "Overpriced Ration"
			food.description = "The shopkeeper charges extra for this ration, but it fills you up just the same."
			food.hunger_satisfy = ConstantsData.MAX_HUNGER
			food.heal_amount = 1
			food.icon_color = Color(0.9, 0.65, 0.3)

		"small_ration":
			food.item_name = "Small Ration"
			food.description = "Not much, but better than nothing."
			# Original: SmallRation satisfies HUNGRY*2/3 = 200
			food.hunger_satisfy = 200.0
			food.heal_amount = 0
			food.icon_color = Color(0.75, 0.5, 0.2)

		"frozen_carpaccio":
			food.item_name = "Frozen Carpaccio"
			food.description = "Thinly sliced frozen meat. Heals and grants a random positive effect."
			# Original: FrozenCarpaccio uses Hunger.HUNGRY/2 = 150
			food.hunger_satisfy = 150.0
			food.heal_amount = 5
			food.random_effect = false  # Uses custom carpaccio logic
			food.icon_color = Color(0.5, 0.7, 0.9)

		"meat_pie":
			food.item_name = "Meat Pie"
			food.description = "A hearty crafted pie. Fully satisfies hunger and heals significantly."
			food.hunger_satisfy = ConstantsData.MAX_HUNGER
			food.heal_amount = 30
			food.icon_color = Color(0.9, 0.6, 0.2)

		_:
			food.item_name = "Unknown Food"
			food.description = "Some kind of food."
			food.hunger_satisfy = ConstantsData.MAX_HUNGER * 0.25

	return food

## Override eat for frozen

