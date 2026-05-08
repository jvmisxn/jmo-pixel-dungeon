class_name WebBlob
extends Blob
## Spider webs. Roots characters that walk into them, then clears.

func _init() -> void:
	super._init()
	blob_id = "web"
	blob_name = "Web"
	spread_rate = 0.0  # Webs don't spread
	decay_rate = 0.0  # Webs don't decay naturally

func affect_char(ch: Char) -> void:
	if not ch.has_buff("Rooted"):
		var root: Rooted = Rooted.new()
		root.set_duration(3.0)
		ch.add_buff(root)
		if MessageLog:
			MessageLog.add_warning("%s is caught in webs!" % ch.name)
	# Clear web at that cell after triggering
	density[ch.pos] = 0.0
