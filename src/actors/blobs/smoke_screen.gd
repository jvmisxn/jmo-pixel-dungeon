class_name SmokeScreen
extends Blob
## A drifting cloud of smoke that blinds sight lines through it.
##
## Source fidelity (Shattered Pixel Dungeon `SmokeScreen.java`): SmokeScreen is a
## bare `Blob` subclass with NO `evolve()` override and NO character effects -- it
## only exists to be rendered (SPD pours a SMOKE speck emitter) and to block
## vision. The LOS blocking itself lives in the level's field-of-view pass, not on
## the blob: SPD's `Level.updateFieldOfView` marks every cell where the smoke's
## `cur[i] > 0` as blocking for non-ally viewers. This port keeps that split --
## `Level.update_fov()` walks a smoke blob's `active_cells` and blocks each -- so
## SmokeScreen here likewise carries no `affect_char()` override and just inherits
## the base volume-conserving diffusion + decay.
##
## SPD's canonical seeder is the alchemical Smoke Bomb (a `Bomb` that seeds
## SmokeScreen across a radius-2 blast on explode). That item is not yet ported;
## see docs/memory/backlog.md for the remaining seeder gap. The blob and its LOS
## hook are complete and covered so the seeder can be wired in cheaply later.

func _init() -> void:
	super._init()
	blob_id = "smoke_screen"
	blob_name = "Smoke Screen"
	# Diffuses and thins like SPD's base-Blob smoke, but lingers a touch longer
	# than damaging gases so the screen actually shrouds for several turns.
	spread_rate = 0.35
	decay_rate = 0.05
