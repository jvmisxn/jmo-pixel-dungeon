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

	var hunger_before: float = 0.0
	var hp_before: int = hero.hp
	var hp_max_before: int = hero.hp_max

	# Satisfy hunger
	var hunger_buff: Variant = hero.get_buff("Hunger") if hero.has_method("get_buff") else null
	if hunger_buff != null and hunger_buff.has_method("satisfy"):
		hunger_before = hunger_buff.hunger_value
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

	if hero.has_method("on_food_eaten"):
		hero.on_food_eaten(self, hunger_before, hp_before, hp_max_before)

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
## Original: MysteryMeat.effect() — Random.Int(5); case 4 does nothing.
func _apply_random_effect(hero: Char) -> void:
	_mystery_effect(hero, randi_range(0, 4))

## Effect body with an explicit roll so headless tests can drive each case.
func _mystery_effect(hero: Char, roll: int) -> void:
	if hero == null or not hero.has_method("add_buff"):
		return
	match roll:
		0:
			# Original: Buff.affect(hero, Burning.class).reignite(hero)
			var burn: Variant = hero.get_buff("Burning") if hero.has_method("get_buff") else null
			if burn == null:
				burn = Burning.new()
				hero.add_buff(burn)
			if burn.has_method("reignite"):
				burn.reignite()
			if MessageLog:
				MessageLog.add_negative("Oh no, it's hot!")
		1:
			# Original: Buff.prolong(hero, Roots.class, Roots.DURATION*2)
			var roots: Variant = hero.get_buff("Rooted") if hero.has_method("get_buff") else null
			if roots == null:
				roots = Rooted.new()
				hero.add_buff(roots)
			roots.set_duration(Rooted.BASE_DURATION * 2.0)
			if MessageLog:
				MessageLog.add_negative("You can't feel your legs!")
		2:
			# Original: Buff.affect(hero, Poison.class).set(hero.HT / 5)
			var poison: Poison = Poison.new()
			poison.set_duration(float(hero.ht) / 5.0)
			hero.add_buff(poison)
			if MessageLog:
				MessageLog.add_negative("You are not feeling well.")
		3:
			# Original: Buff.prolong(hero, Slow.class, Slow.DURATION)
			var slow: Variant = hero.get_buff("Slow") if hero.has_method("get_buff") else null
			if slow == null:
				slow = Slow.new()
				hero.add_buff(slow)
			slow.set_duration(Slow.BASE_DURATION)
			if MessageLog:
				MessageLog.add_negative("You are stuffed.")
		_:
			# Case 4: no effect.
			pass

## Apply a random effect for frozen carpaccio.
## Original: FrozenCarpaccio.effect() — Random.Int(5); case 4 does nothing.
func _apply_carpaccio_buff(hero: Char) -> void:
	_carpaccio_effect(hero, randi_range(0, 4))

## Effect body with an explicit roll so headless tests can drive each case.
func _carpaccio_effect(hero: Char, roll: int) -> void:
	if hero == null or not hero.has_method("add_buff"):
		return
	match roll:
		0:
			# Original: Buff.affect(hero, Invisibility.class, Invisibility.DURATION)
			hero.add_buff(Invisibility.new())
			if MessageLog:
				MessageLog.add_positive("You feel your body fade from sight.")
		1:
			# Original: Barkskin.conditionallyAppend(hero, hero.HT / 4, 1)
			Barkskin.conditionally_append(hero, int(hero.ht / 4.0), 1)
			if MessageLog:
				MessageLog.add_positive("Your skin hardens.")
		2:
			# Original: PotionOfHealing.cure(hero) — debuff cleanse only
			Potion.PotionHealing.cure(hero)
			if MessageLog:
				MessageLog.add_positive("You feel refreshed.")
		3:
			# Original: hero.HP = min(HP + HT/4, HT)
			if hero.has_method("heal"):
				hero.heal(int(hero.ht / 4.0))
			if MessageLog:
				MessageLog.add_positive("You feel better!")
		_:
			# Case 4: no effect.
			pass

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
		"mystery_meat":
			# Original: MysteryMeat.value() = 5 * quantity
			return 5 * quantity
		"chargrilled_meat":
			# Original: ChargrilledMeat.value() = 8 * quantity
			return 8 * quantity
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

		"chargrilled_meat":
			food.item_name = "Chargrilled Meat"
			food.description = "The meat of a slain monster, chargrilled to remove any nasty effects."
			# Original: ChargrilledMeat energy = Hunger.HUNGRY/2 = 150
			food.hunger_satisfy = 150.0
			food.heal_amount = 0
			food.icon_color = Color(0.6, 0.35, 0.2)

		"frozen_carpaccio":
			food.item_name = "Frozen Carpaccio"
			food.description = "A slice of frozen raw meat. Eating it may grant a random positive effect."
			# Original: FrozenCarpaccio energy = Hunger.HUNGRY/2 = 150, no flat heal
			food.hunger_satisfy = 150.0
			food.heal_amount = 0
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

## Whether this food item is frozen carpaccio (grants a random positive buff).
func _is_carpaccio() -> bool:
	return item_id == "frozen_carpaccio"
