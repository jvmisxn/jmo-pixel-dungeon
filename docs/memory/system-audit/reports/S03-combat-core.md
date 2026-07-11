# Actor / Char combat core — Audit

- Files: `src/actors/actor.gd` (96 lines), `src/actors/char.gd` (607 lines)
- Read in full: yes
- Verdict: **needs-hardening** — combat resolution is faithful and well-structured, but Char ships no combat-state serializer (subclasses re-roll it by hand), and two damage/hit formulas diverge from SPD (uniform damage roll, invisible-only surprise).

## Improvements
- [P1] `Char` provides **no `serialize()`/`deserialize()` for combat state** — only the `_serialize_buffs`/`_deserialize_buffs` helpers (`char.gd:450-483`). `Actor.serialize()` returns just `actor_id/pos/active` (`actor.gd:53-70`). So hp, hp_max, ht, str_val, shielding, combat stats, and the alive/flying/paralysed flags are entirely each subclass's responsibility — one forgotten field silently loses that state on save. Add `serialize_char()`/`deserialize_char()` on Char that capture the combat block + buffs, mirroring the `serialize_actor()` pattern, and have subclasses super-call it.
- [P1] `damage_roll()` uses **uniform `randi_range(min,max)`** (`char.gd:70`), but SPD `Char.damageRoll()` returns `Random.NormalIntRange(min,max)` (bell-curved, e.g. Snake `NormalIntRange(1,4)`). Mob/attack damage in the port has materially higher variance than SPD — swingier hits both ways. The `dr_roll()` armor code right below already implements the correct two-roll average (`char.gd:230,235`); apply the same averaging to `damage_roll()`.
- [P1] **Guaranteed hits fire only for invisible attackers** (`char.gd:153`). In SPD an attack is a surprise (can't miss) whenever the *target doesn't see the attacker* — sleeping/unaware mobs, stealthed hero — and Assassin gets +50% surprise damage off that flag. The port has no `enemy_seen`/awareness path, so sneak attacks vs. sleeping mobs roll a normal accuracy check. Thread a `surprise` bool (target FOV / Sleep / Paralysis) into `attack()`/`hit()` and expose it for the Assassin damage bonus.
- [P2] Non-`Buff` nodes can be attached via `add_buff` (it falls back to `get_script().get_path()` for the type key, `char.gd:378`), but `has_buff`/`get_buff`/`remove_buff_by_id` only match `Buff` instances (`char.gd:418-435`). Such a buff would be un-findable and un-removable. Either require `Buff` in `add_buff` or make the lookups handle the script-path key too.
- [P3] `die()` calls `_try_prevent_death` (`char.gd:347`) but if a subclass prevents death without restoring HP, the char is left `is_alive=true` at `hp<=0` and the next `take_damage` re-enters `die()`. Add a guard/assert that prevention must leave `hp>0`.

## Optimizations
- [P2] `_innate_immunities()` allocates a fresh `Array[String]` on **every** `is_immune()` call (`char.gd:551-558`), and `is_immune` runs in the hot attack/take_damage path (buff-attach, Doom, per-source resist). Return a cached/`const` array (base is always empty) so no per-hit allocation.
- [P2] Buff lookups (`has_buff`/`get_buff`) are O(n) string scans; a single `attack()`→`take_damage()` does ~12 of them (Berserk, Fury, Weakness, Vulnerable, Invulnerable, Doom, Frozen, Sleep, Terror, Dread, Charm, Bless/Hex/Daze ×2). Maintain a `Dictionary[buff_id -> Array[Buff]]` index updated in add/remove for O(1) checks.
- [P3] Spatial helpers `distance_to`/`is_adjacent`/`can_see` are duplicated verbatim in `Actor` (`actor.gd:77-96`) and fully overridden in `Char` (`char.gd:585-607`). `Blob extends Actor` uses the base copies, so they can't be deleted — but Char's `distance_to`/`is_adjacent` are identical and could `super()`-delegate to cut drift risk.

## Additions
- [P2] No headless combat tests. Add round-trip/asserts for the damage pipeline: `damage_roll` distribution, `hit()` boundary (infinite eva/acc at 1e6, `char.gd:157-160`), armor `dr_roll` averaging, shield-then-HP ordering (`char.gd:305-317`), and Doom×1.67 / Vulnerable×1.33 stacking order. This is the most-exercised, least-covered code in the game.
- [P2] Resistances/immunities are deliberately **skipped for `Char`-sourced (physical attack) damage** (`char.gd:273-275`). SPD applies `resist(src.getClass())` to attack damage too (e.g. an elemental mob's melee). Confirm the port has no physically-typed attackers that need resist, or route attack damage through `resist()` as well.

## Save/load & coupling notes
- Persistence contract: `Actor.serialize_actor()` is the only base serializer; `serialize()` aliases it. Char adds buff (de)serialization by `_script_path` + `deserialize` (`char.gd:457-483`) but **no combat block** — full combat-state save fidelity depends entirely on Hero/Mob subclasses. This is the S03↔S01 seam and the main data-loss risk here.
- Autoload coupling: `TurnManager` (register/spend/remove, `actor.gd:33-50`), `EventBus.status_effect_applied` (`char.gd:394,404`), `ConstantsData` (`pos_to_x/y`), plus static cross-class calls to `Barkskin.current_level` (`char.gd:227`) and `Buff` typing. `level` is intentionally untyped (`actor.gd:11`) to dodge the circular dep. All guarded with `if TurnManager`/`has_method` — no hard crashes if an autoload is absent.

## Research notes
- SPD `Char.damageRoll()` → `Random.NormalIntRange(min,max)`; Snake uses `NormalIntRange(1,4)`. Confirms uniform port roll is a fidelity gap. [Snake.java, PD Wiki Combat]
- SPD surprise: an attack the target can't see "can't miss (but can still deal 0)"; Assassin +50% surprise damage; surprise = target doesn't see attacker at strike time — broader than the port's invisible-only gate. [PD Wiki Attacking, Steam discussion]
- Hit formula `Random.Float(acuStat) >= Random.Float(defStat)` with Bless/Hex/Daze multipliers (`char.gd:148-181`) matches SPD `Char.hit` faithfully — no change needed.

Sources: [Snake.java](https://github.com/00-Evan/shattered-pixel-dungeon/blob/master/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/actors/mobs/Snake.java), [PD Wiki — Attacking](https://pixeldungeon.fandom.com/wiki/Game_mechanics/Attacking), [PD Wiki — Combat](https://pixeldungeon.fandom.com/wiki/Shattered_Pixel_Dungeon/Combat)
