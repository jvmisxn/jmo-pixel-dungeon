extends RefCounted
## Surprise-attack fidelity: a guaranteed hit lands whenever the defender is
## unaware of the attacker (invisible, sleeping, wandering, out of sight), not
## only when the attacker is invisible. Mirrors SPD's surprised-defender rule
## where an unaware defender has 0 effective evasion.

# WIDTH is 32 (ConstantsData.WIDTH); pick same-row cells 1 apart so the level-less
# can_see() fallback (Chebyshev distance <= 8) reports the attacker as visible,
# and a cell 10 rows away so it reports the attacker as unseen.
const NEAR_A: int = 5 * 32 + 10  # attacker cell adjacent to the mob
const MOB_CELL: int = 5 * 32 + 11
const FAR_A: int = 15 * 32 + 10  # attacker cell 10 tiles from the mob

func run(t: Object) -> void:
	_test_base_char_only_surprised_by_invisible(t)
	_test_mob_surprise_states(t)
	_test_guaranteed_hit_when_surprised(t)

func _make_attacker(cell: int) -> Char:
	var a: Char = Char.new()
	a.name = "Attacker"
	a.pos = cell
	a.attack_skill = 1
	a.is_alive = true
	return a

func _make_mob(cell: int, mob_state: int) -> Mob:
	var m: Mob = Mob.new()
	m.setup(20, 10, 1000, 1, 4, 0)  # huge defense_skill so normal hits usually miss
	m.pos = cell
	m.state = mob_state
	m.is_alive = true
	return m

func _test_base_char_only_surprised_by_invisible(t: Object) -> void:
	var attacker: Char = _make_attacker(NEAR_A)
	var defender: Char = _make_attacker(MOB_CELL)

	t.check(not defender.is_surprised_by(attacker),
		"Base Char is not surprised by a visible attacker")
	attacker.invisible = 1
	t.check(defender.is_surprised_by(attacker),
		"Base Char is surprised by an invisible attacker (preserved behavior)")

	attacker.free()
	defender.free()

func _test_mob_surprise_states(t: Object) -> void:
	var attacker: Char = _make_attacker(NEAR_A)

	var sleeping: Mob = _make_mob(MOB_CELL, Mob.AIState.SLEEPING)
	t.check(sleeping.is_surprised_by(attacker), "Sleeping mob is surprised")

	var wandering: Mob = _make_mob(MOB_CELL, Mob.AIState.WANDERING)
	t.check(wandering.is_surprised_by(attacker), "Wandering (unaware) mob is surprised")

	var passive: Mob = _make_mob(MOB_CELL, Mob.AIState.PASSIVE)
	t.check(passive.is_surprised_by(attacker), "Passive mob is surprised")

	var hunting_seen: Mob = _make_mob(MOB_CELL, Mob.AIState.HUNTING)
	t.check(not hunting_seen.is_surprised_by(attacker),
		"Hunting mob that can see the attacker is NOT surprised")

	var hunting_paralysed: Mob = _make_mob(MOB_CELL, Mob.AIState.HUNTING)
	hunting_paralysed.paralysed = 1
	t.check(hunting_paralysed.is_surprised_by(attacker),
		"Paralysed hunting mob is surprised")

	var hunting_invis: Mob = _make_mob(MOB_CELL, Mob.AIState.HUNTING)
	attacker.invisible = 1
	t.check(hunting_invis.is_surprised_by(attacker),
		"Hunting mob is surprised by an invisible attacker")
	attacker.invisible = 0

	# Hunting but the attacker is out of sight (10 tiles away) -> lost track -> surprised.
	var far_attacker: Char = _make_attacker(FAR_A)
	var hunting_blind: Mob = _make_mob(MOB_CELL, Mob.AIState.HUNTING)
	t.check(hunting_blind.is_surprised_by(far_attacker),
		"Hunting mob that cannot see the attacker is surprised")

	attacker.free()
	far_attacker.free()
	sleeping.free()
	wandering.free()
	passive.free()
	hunting_seen.free()
	hunting_paralysed.free()
	hunting_invis.free()
	hunting_blind.free()

func _test_guaranteed_hit_when_surprised(t: Object) -> void:
	seed(0xC0FFEE)  # deterministic RNG for the miss-counting assertion below
	var attacker: Char = _make_attacker(NEAR_A)
	const ITERS: int = 200

	# Sleeping (surprised) defender: every attack is guaranteed to land.
	var sleeping: Mob = _make_mob(MOB_CELL, Mob.AIState.SLEEPING)
	var surprised_hits: int = 0
	for _i: int in range(ITERS):
		if Char.hit(attacker, sleeping):
			surprised_hits += 1
	t.check(surprised_hits == ITERS,
		"Surprised (sleeping) defender is hit on every attack")

	# Aware hunting defender with the same huge evasion: normal roll can miss.
	var hunting: Mob = _make_mob(MOB_CELL, Mob.AIState.HUNTING)
	var aware_hits: int = 0
	for _j: int in range(ITERS):
		if Char.hit(attacker, hunting):
			aware_hits += 1
	t.check(aware_hits < ITERS,
		"Aware defender with high evasion can still evade (surprise is what guarantees the hit)")

	attacker.free()
	sleeping.free()
	hunting.free()
