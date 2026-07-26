extends RefCounted
## Badge registry consistency coverage (audit:S29).
##
## Regression guard for the badge-count denominator bug: `_ALL_BADGE_IDS`
## once omitted `strength_15`/`first_death`/`death_by_goo`, so the badge
## screen could read e.g. 26/23. This scans badges.gd for every id that
## `unlock()` can actually receive (literal calls, threshold templates,
## BOSS_BADGE_MAP values) and asserts each one is counted, uniquely listed,
## and carries a real name + description.

const BADGES_SOURCE := "res://src/autoloads/badges.gd"

func _reachable_badge_ids() -> Array[String]:
	var ids: Dictionary[String, bool] = {}
	# Literal unlock("...") call sites.
	var source: String = FileAccess.get_file_as_string(BADGES_SOURCE)
	var regex := RegEx.new()
	regex.compile("unlock\\(\"([a-z0-9_]+)\"\\)")
	for m: RegExMatch in regex.search_all(source):
		ids[m.get_string(1)] = true
	# Templated threshold unlocks.
	for threshold: int in BadgesManager.ENEMIES_SLAIN_THRESHOLDS:
		ids["enemies_slain_%d" % threshold] = true
	for threshold: int in BadgesManager.GOLD_THRESHOLDS:
		ids["gold_collected_%d" % threshold] = true
	# Boss kill badges routed through BOSS_BADGE_MAP.
	for badge_id: String in BadgesManager.BOSS_BADGE_MAP.values():
		ids[String(badge_id)] = true
	var result: Array[String] = []
	for id: String in ids.keys():
		result.append(id)
	return result

func run(t: Object) -> void:
	var badges: BadgesManager = BadgesManager.new()

	var all_ids: Array[String] = BadgesManager._ALL_BADGE_IDS
	t.check(badges.get_total_badge_count() == all_ids.size(),
		"get_total_badge_count matches _ALL_BADGE_IDS size")

	# No duplicate entries in the master list.
	var seen: Dictionary[String, bool] = {}
	for id: String in all_ids:
		t.check(not seen.has(id), "_ALL_BADGE_IDS has no duplicate '%s'" % id)
		seen[id] = true

	# Every id unlock() can receive must be counted in the denominator.
	var reachable: Array[String] = _reachable_badge_ids()
	t.check(reachable.size() >= 25,
		"source scan found the unlockable badge ids (got %d)" % reachable.size())
	for id: String in reachable:
		t.check(seen.has(id),
			"unlockable badge '%s' is counted in _ALL_BADGE_IDS" % id)

	# Every counted badge must be reachable — no phantom entries inflating
	# the denominator the other way.
	for id: String in all_ids:
		t.check(reachable.has(id),
			"counted badge '%s' has an unlock() path" % id)

	# Every counted badge carries real display text. Names can't be told
	# apart from the capitalize fallback (e.g. "First Victory"), but the
	# description fallback is "" so it reliably flags unregistered ids.
	for id: String in all_ids:
		t.check(badges.get_badge_name(id) != "",
			"badge '%s' has a display name" % id)
		t.check(badges.get_badge_description(id) != "",
			"badge '%s' has a description" % id)

	badges.free()
