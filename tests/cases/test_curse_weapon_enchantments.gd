extends RefCounted
## Regression for audit:S13 — curse weapon enchantments were unreachable:
##   * WeaponEnchantment.proc() matched only non-curse ids, so the implemented
##     _annoying_proc/_sacrificial_proc/_displacing_proc bodies were dead code.
##   * WeaponEnchantment.random_curse() had no callers, so Weapon.random() never
##     produced a cursed weapon that actually carried a curse enchantment.
## These checks pin generation (random_curse + Weapon.random cursed branch) and
## proc dispatch (curse procs fire, non-curse procs still route) deterministically.

func run(t: Object) -> void:
	_check_random_curse_returns_curse(t)
	_check_create_marks_curse(t)
	_check_cursed_weapon_gets_curse_enchant(t)
	_check_sacrificial_proc_dispatches(t)
	_check_displacing_proc_dispatches(t)
	_check_curse_proc_emits_signal(t)
	_check_non_curse_proc_still_routes(t)

## random_curse() must only ever return curse enchantments.
func _check_random_curse_returns_curse(t: Object) -> void:
	for _i in range(40):
		var e: WeaponEnchantment = WeaponEnchantment.random_curse()
		t.check(e != null, "random_curse() returns an enchantment")
		if e == null:
			continue
		t.check(e.is_curse, "random_curse() enchant '%s' is flagged is_curse" % e.enchant_id)
		t.check(e.enchant_id in WeaponEnchantment.CURSE_IDS,
			"random_curse() id '%s' is in CURSE_IDS" % e.enchant_id)

## create() must flag the implemented curse ids as curses.
func _check_create_marks_curse(t: Object) -> void:
	for eid: String in ["annoying", "sacrificial", "displacing"]:
		var e: WeaponEnchantment = WeaponEnchantment.create(eid)
		t.check(e != null and e.is_curse, "create('%s') is a curse enchantment" % eid)

## Weapon.random() cursed branch now attaches a curse enchantment so its proc
## can fire on hit (previously cursed weapons carried no enchantment at all).
func _check_cursed_weapon_gets_curse_enchant(t: Object) -> void:
	var saw_cursed_with_enchant := false
	for _i in range(200):
		var w: Weapon = Weapon.new()
		w.random()
		if w.cursed:
			t.check(w.enchantment != null,
				"cursed weapon carries an enchantment")
			if w.enchantment != null:
				t.check(w.enchantment.is_curse,
					"cursed weapon's enchantment is a curse ('%s')" % w.enchantment.enchant_id)
				saw_cursed_with_enchant = true
			break
	t.check(saw_cursed_with_enchant, "at least one cursed weapon rolled in 200 tries")

## Sacrificial dispatch: proc reaches _sacrificial_proc, which deals self-damage
## to the attacker and returns amplified (1.3x) damage.
func _check_sacrificial_proc_dispatches(t: Object) -> void:
	var e: WeaponEnchantment = WeaponEnchantment.create("sacrificial")
	var attacker := _StubAttacker.new()
	var damage := 100
	var out: int = e.proc(null, attacker, null, damage)
	t.check(out == int(float(damage) * 1.3),
		"_sacrificial_proc amplifies damage to 1.3x (got %d)" % out)
	t.check(attacker.damage_taken > 0,
		"_sacrificial_proc bites the attacker (took %d)" % attacker.damage_taken)

## Displacing dispatch: proc reaches _displacing_proc, which teleports the
## defender to the level's random passable cell via move_to().
func _check_displacing_proc_dispatches(t: Object) -> void:
	var e: WeaponEnchantment = WeaponEnchantment.create("displacing")
	var defender := _StubDefender.new()
	defender.pos = 5
	defender.level = _StubLevel.new()
	e.proc(null, null, defender, 10)
	t.check(defender.moved_to == _StubLevel.TARGET_POS,
		"_displacing_proc teleports the defender to the level's passable cell")

## Curse procs must still emit the EventBus.enchantment_proc signal (visual hook).
func _check_curse_proc_emits_signal(t: Object) -> void:
	if EventBus == null:
		t.check(true, "EventBus unavailable; skipping signal check")
		return
	var sink := _SignalSink.new()
	EventBus.enchantment_proc.connect(sink.on_proc)
	var e: WeaponEnchantment = WeaponEnchantment.create("annoying")
	e.proc(null, null, null, 10)
	EventBus.enchantment_proc.disconnect(sink.on_proc)
	t.check(sink.last_id == "annoying",
		"_annoying_proc emits enchantment_proc('annoying') (got '%s')" % sink.last_id)

## Non-curse dispatch must be unaffected: shocking still adds its flat bonus.
func _check_non_curse_proc_still_routes(t: Object) -> void:
	var e: WeaponEnchantment = WeaponEnchantment.create("shocking")
	var attacker := _StubAttacker.new()
	var defender := _StubDefender.new()
	var damage := 100
	var out: int = e.proc(null, attacker, defender, damage)
	t.check(out > damage, "_shocking_proc still adds bonus damage (got %d)" % out)

# --- Stubs ---------------------------------------------------------------

class _StubAttacker extends RefCounted:
	var pos: int = 0
	var damage_taken: int = 0
	func take_damage(amount: int, _source: Variant) -> void:
		damage_taken += amount

class _StubDefender extends RefCounted:
	var pos: int = 0
	var level: Variant = null
	var moved_to: int = -1
	func move_to(new_pos: int) -> void:
		moved_to = new_pos

class _StubLevel extends RefCounted:
	const TARGET_POS: int = 42
	func random_passable_cell() -> int:
		return TARGET_POS

class _SignalSink extends RefCounted:
	var last_id: String = ""
	func on_proc(enchant_id: String, _a_pos: int, _d_pos: int) -> void:
		last_id = enchant_id
