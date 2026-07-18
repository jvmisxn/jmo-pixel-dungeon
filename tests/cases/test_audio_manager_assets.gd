extends RefCounted

func run(t: Object) -> void:
	var manager: AudioManagerNode = AudioManagerNode.new()
	manager._ensure_audio_buses()
	manager._create_players()
	manager._load_real_sfx()
	manager._load_real_music()

	t.check(manager.SFX_MANIFEST.has("item"), "SFX manifest includes item pickup")
	t.check(manager.SFX_MANIFEST.has("door_open"), "SFX manifest includes door open")
	t.check(manager.SFX_MANIFEST.has("zap"), "SFX manifest includes zap")
	t.check(manager.MUSIC_MANIFEST.has("theme_2"), "music manifest includes title theme")
	t.check(manager.MUSIC_MANIFEST.has("sewers_1"), "music manifest includes sewers ambient")

	t.check(manager._sfx_cache.size() >= manager.SFX_MANIFEST.size(), "SFX cache loads manifest entries")
	t.check(manager._music_cache.size() >= manager.MUSIC_MANIFEST.size(), "music cache loads manifest entries")
	t.check(manager._sfx_cache.has("item"), "SFX cache resolves item pickup")
	t.check(manager._sfx_cache.has("door_open"), "SFX cache resolves door open")
	t.check(manager._music_cache.has("theme_2"), "music cache resolves title theme")
	t.check(manager._music_cache.has("sewers_1"), "music cache resolves sewers ambient")

	manager.free()
