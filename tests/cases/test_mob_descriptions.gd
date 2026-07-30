extends RefCounted

## Every factory-spawnable mob must carry a real (upstream-sourced) description
## so the examine-mode WndInfoMob never falls back to placeholder text.

const FACTORY_IDS: Array[String] = [
	"rat", "albino", "fetid_rat", "gnoll", "crab", "great_crab", "snake",
	"slime", "caustic_slime", "swarm", "gnoll_trickster",
	"skeleton", "thief", "guard", "necromancer", "bandit",
	"bat", "brute", "armored_brute", "shaman", "spinner", "dm100", "dm200", "dm201",
	"warlock", "monk", "golem", "elemental",
	"succubus", "eye", "scorpio", "ripper",
	"piranha", "mimic", "animated_statue", "golden_statue", "wraith", "bee",
	"goo", "tengu", "dm300", "king", "yog",
]

## mob_id -> distinctive upstream phrase from actors.properties (SPD source).
const UPSTREAM_PHRASES: Dictionary = {
	"rat": "Marsupial rats are aggressive but rather weak denizens",
	"armored_brute": "powerful armor to show their status",
	"snake": "capable of quickly slithering around blows",
	"skeleton": "disintegrate in an explosion of bones",
	"bat": "replenish their health with each successful attack",
	"warlock": "warlocks came to power in the city",
	"eye": "floating balls of pent up demonic energy",
	"mimic": "magical creatures which can take any shape they wish",
	"king": "uncovered secrets which gave him tremendous power over life and death",
	"yog": "Yog-Dzewa is an Old God",
}

func run(t: Object) -> void:
	for mob_id: String in FACTORY_IDS:
		var mob: Mob = MobFactory.create_mob(mob_id)
		t.check(mob != null, "factory creates '%s'" % mob_id)
		if mob == null:
			continue
		t.check(mob.description.strip_edges().length() >= 40,
			"'%s' has a substantial description" % mob_id)
		t.check(not mob.description.contains("_"),
			"'%s' description has no upstream markup underscores" % mob_id)

	for mob_id: String in UPSTREAM_PHRASES:
		var mob: Mob = MobFactory.create_mob(mob_id)
		if mob == null:
			continue
		t.check(mob.description.contains(str(UPSTREAM_PHRASES[mob_id])),
			"'%s' description matches upstream SPD text" % mob_id)

	var fist: Mob = YogFist.new()
	t.check(fist.description.contains("aspect of Yog-Dzewa's power"),
		"yog_fist gained its upstream description")
