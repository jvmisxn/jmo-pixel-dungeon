extends RefCounted
## Locks Poison's per-tick damage timing to upstream SPD.
##
## SPD `Poison.act()` deals `(int)(left/3)+1` damage using `left` BEFORE
## decrementing it, so a freshly applied poison ticks at its highest value.
## The port's base `Buff.act()` decrements `time_left` first, which used to
## shift every tick one lower and under-deal total poison. `Poison.act()`
## now damages before decrementing to match.

func run(t: Object) -> void:
	_test_first_tick_uses_full_duration(t)
	_test_full_duration_total_matches_spd(t)
	_test_tick_count_unchanged(t)

## First tick of a 10-turn poison must read left=10 -> (10/3)+1 = 4 damage,
## not the pre-fix left=9 -> 4 (same here) — use a value where the tiers differ:
## left=9 -> 4 vs left=8 -> 3.
func _test_first_tick_uses_full_duration(t: Object) -> void:
	var c: Char = Char.new()
	c.hp = 100
	c.hp_max = 100
	c.ht = 100
	c.add_buff(Poison.create(9.0))

	c.process_buffs()  # one tick

	# Upstream first tick reads left=9 -> (9/3)+1 = 4. Pre-fix read left=8 -> 3.
	t.check(c.hp == 96, "First poison tick uses pre-decrement duration (4 damage at left=9)")
	var p: Poison = c.get_buff("Poison") as Poison
	t.check(p != null and p.time_left == 8.0, "time_left decremented once after the tick")

	c.free()

## Full 10-turn poison should deal 25 total (4+4+3+3+3+2+2+2+1+1), matching SPD,
## not the pre-fix 22.
func _test_full_duration_total_matches_spd(t: Object) -> void:
	var c: Char = Char.new()
	c.hp = 100
	c.hp_max = 100
	c.ht = 100
	c.add_buff(Poison.create(10.0))

	for _i: int in range(10):
		c.process_buffs()

	t.check(c.hp == 75, "10-turn poison deals SPD total of 25 damage (was 22 pre-fix)")
	t.check(not c.has_buff("Poison"), "Poison expires after its full duration")

	c.free()

## Damaging before decrement must not add an extra tick: a 10-turn poison still
## resolves in exactly 10 ticks (no tick from left=0).
func _test_tick_count_unchanged(t: Object) -> void:
	var c: Char = Char.new()
	c.hp = 1000
	c.hp_max = 1000
	c.ht = 1000
	c.add_buff(Poison.create(3.0))

	# left=3 -> 2, left=2 -> 1, left=1 -> 1  => 4 total over 3 ticks, then gone.
	c.process_buffs()
	c.process_buffs()
	c.process_buffs()
	t.check(c.hp == 996, "3-turn poison deals 2+1+1 = 4 over exactly 3 ticks")
	t.check(not c.has_buff("Poison"), "No extra tick fires from left=0")

	c.free()
