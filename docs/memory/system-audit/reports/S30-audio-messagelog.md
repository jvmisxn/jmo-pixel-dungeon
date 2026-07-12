# Audio & MessageLog — Audit

- Files: `src/autoloads/audio_manager.gd` (609 lines), `src/autoloads/message_log.gd` (69 lines)
- Read in full: yes
- Verdict: needs-hardening — both singletons are clean and correctly wired for the common path, but AudioManager ships a dead boss-finale music path and a fallback layer that produces pure silence while advertising procedural tones, and MessageLog is a process-lifetime singleton that is never reset between runs.

## Improvements
- [P1] **MessageLog is never reset between runs and never persisted** — `_entries` lives on the autoload for the whole process. `clear()` has no external caller anywhere (only self-reference at `message_log.gd:55`), and SaveManager does not serialize the log. Starting a new hero or loading a save carries the previous run's scrollback into the new game, and `current_turn` (driven by `TurnManager._round_count`, `turn_manager.gd:269`) can jump backward, producing out-of-order "--- Turn N ---" headers in `game_log_display.gd`. SPD ties the message log to the active run. — Direction: call `MessageLog.clear()` + reset `current_turn = 0` on new-game start and on load; optionally serialize the last ~20 entries with the save. (message_log.gd is in TRUNCATED_FILES.txt — no autofix.)
- [P2] **Boss-finale music path is fully dead** — `play_region_music(..., is_boss_finale)` and the caves/city/halls `boss_finale` tracks (`audio_manager.gd:281-284`, entries at :61/:69/:77) are never triggered. The only caller, `game_scene.gd:493`, always passes `play_region_music(region, false, true)` (plain boss) and never the finale flag; `grep` finds zero `is_boss_finale`/`boss_finale` callers. SPD swaps to the finale track for boss phase 2 (DM-300 rebuild, Dwarf King summon phase, Yog fists). — Direction: emit a boss-phase-change signal and pass `is_boss_finale=true` from the boss level on phase 2.
- [P2] **Procedural SFX fallback produces only silence** — the header comment promises "Falls back to procedural generation only if real assets are missing," but every one of the ~34 `_gen_*` helpers (`audio_manager.gd:503-609`) returns `_gen_silent(0.05)`. If `res://assets/spd/sounds/` is empty or unreadable, `_generate_fallback_sfx()` fills the cache with silent clips — the game runs mute rather than procedurally scored, and ~130 lines exist only to alias silence. — Direction: either implement real tone synthesis or collapse the block to a single silent stub and correct the comment.
- [P3] **`set_music_muted(false)` restarts the track from the top** — unmuting calls `_music_player.play()` after mute stopped it (`audio_manager.gd:328-335`), so playback resumes at position 0 instead of where it left off, and the crossfade player state is not restored. Minor but audible. — Direction: track playback position (or `stream_paused`) across mute.

## Optimizations
- [P3] **`_get_free_sfx_player()` always steals channel 0 when the pool is saturated** (`audio_manager.gd:364-369`) — under an 8+ simultaneous-SFX burst it repeatedly cuts the same player mid-clip. A round-robin or oldest-player index would spread the churn. Low impact at normal SFX rates.
- [P3] **`_weighted_random_pick` recomputes `total` every call** — trivial; only invoked on track change, not per-frame. Note only.

## Additions
- [P2] Persist the last N message-log entries with the save so the log survives reload (SPD shows recent messages after load).
- [P3] No unit tests cover `_weighted_random_pick` (weight distribution) or the message-log prune/`get_recent` boundary — both are pure and easily testable if a GDScript test harness lands.
- [P3] `play_theme_finale()` (`audio_manager.gd:265-267`) is an unwired public hook (no callers) intended for ascension victory — wire it into the win-transition or drop it. Left in place as an intended stub, not auto-removed.

## Save/load & coupling notes
- Volume/mute state IS persisted correctly: SaveManager settings round-trips `sfx_volume`/`music_volume`/`sfx_muted`/`music_muted` (`save_manager.gd:607-651`) and mirrors them onto GameManager `setting_*` fields via wnd_settings/title_scene. **Minor inconsistency:** on apply, `save_manager.gd:642` defaults a missing `music_volume` to `1.0`, but `DEFAULT_SETTINGS` (`:608`) and the AudioManager default (`:15`) are `0.5` — a missing key yields louder-than-default music. (In save_manager, not this system; note only.)
- AudioManager holds no run state that needs saving beyond volume; MessageLog holds run-scoped scrollback that is neither saved nor reset (P1 above).
- Coupling: AudioManager is a clean leaf (only touches AudioServer + res:// assets). MessageLog is a clean leaf too; `game_log_display.gd` is its sole reactive consumer (subscribes `message_added`/`log_cleared`, reads `get_recent`).

## Research notes
- SPD (`SPDSettings` / `Music.INSTANCE.playTracks`): region playlists with weighted random selection — the port's `REGION_TRACKS` + `_weighted_random_pick` faithfully mirror this, including the theme_2-first ordering (`play_theme_music`, :256-261).
- SPD plays a distinct boss "finale" track during the second phase of caves/city/halls bosses; the port has the tracks and the parameter but no trigger — the P2 finding above.
- Verified via repo-wide `grep`: `is_boss_finale`/`boss_finale`, `MessageLog.clear`, and `play_theme_finale` have no callers outside their defining files.
