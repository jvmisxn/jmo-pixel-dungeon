# Change Log

## 2026-05-08

- Tags: tooling, workflow, memory
- Added a lightweight repo-local memory system under `docs/memory/`.
- Added canonical files for active context, architecture map, decisions, lessons, backlog, and session-level change summaries.
- Added helper scripts to search memory quickly and append timestamped notes.
- Updated `CLAUDE.md` to point future work toward the concise memory layer before using large historical logs.
- Explicitly positioned the existing Claude-agent logs as legacy deep-reference sources beneath the new concise memory layer.
- Moved bulky historical logs from the repo root into `docs/history/` and added archive `README.md`, `INDEX.md`, and `SUMMARY.md` to preserve accessibility while reducing clutter.
- Added compact memory notes derived from the archive: `archive-backlog.md`, `system-summaries.md`, and `session-checklist.md`.
- Added focused topic notes for persistence, framework-readiness, and SPD-fidelity work.
- Started closing the original-SPD identification gap with a persistent `ItemCatalog` autoload, Journal catalog wiring, and automatic potion/scroll self-identification on use.
- Added a per-run `ItemAppearance` autoload so potions, scrolls, and rings now get deterministic unidentified appearances that persist through save/load.
- Added a persistent `DiscoveryCatalog` for enemies, traps, and plants, and expanded the Journal catalog beyond items-only.
- Extended `DiscoveryCatalog` and the Journal to track weapon enchantments and armor glyphs via proc events and identified inscribed gear.
- Discovery tracking now also records revealed enemies and interacted NPCs, so the Journal catalog is not limited to kills.
- Added groundwork for talents: `TalentData` definitions, hero-owned talent points and levels, save/load support, and read-only talent display in Hero Info.
- Added a spendable talent UI with `WndTalents`, wired it into Hero Info, and added reusable window-content refresh support so talent changes update live.
- Implemented the first live talent effects: Warrior `Hearty Meal`, Mage `Empowering Meal`, Rogue `Cached Rations`, Huntress `Nature's Bounty`, and Duelist `Adventurer's Intuition`.
- Implemented the class intuition pickup hooks: Warrior `Tested Hypothesis`, Mage `Scholar's Intuition`, Rogue `Thief's Intuition`, and Huntress `Survivalist's Intuition`.
- Fixed gold item generation so random gold piles now keep their SPD `items.png` sprite index, and updated the item detail window to use the real item icon instead of a color placeholder.
- Replaced several remaining color/text-only item previews with sheet-backed icons in the shop window, alchemy window, and generic item-selection window.
- Extended that UI art cleanup to picker-style rows as well, including the shop sell picker.
- Fixed the hero combat pipeline so invisibility-based surprise attacks resolve before breaking stealth, and hero combat now routes through equipped weapon enchantment and armor glyph procs.
- Implemented the first combat talent hooks: Rogue `Sucker Punch`, Duelist `Patient Strike`, and Mage `Backup Barrier`.
- Implemented targeted thrown-item resolution through the hero action system, added a real `Shoot` action for `Spirit Bow`, and made Huntress `Followup Strike` a live ranged-to-melee combat hook.
- Hooked Huntress click-to-attack flow into `Spirit Bow`, so clicking a visible distant enemy now auto-shoots instead of always auto-walking into melee when a clear bow shot is available.
- Hardened run-reset and scene-loading loops against stale freed hero/mob references by avoiding typed `Node` iteration over arrays that can still contain invalid instances after death/restart transitions.
- Formalized the Huntress `Spirit Bow` as a dedicated equipment slot instead of a backpack special-case, and updated inventory/status/hero-info UI to reflect the separate melee and bow loadout.
- Fixed a regression from the bow-slot formalization where ranged attacks animated but exited before resolving because `throw_item` still only accepted melee-weapon or backpack ownership, not the dedicated `spirit_bow` slot.
- Routed wand zaps through the hero action system so targeted wand use now consumes a proper turn instead of resolving instantly from the item window callback.
- Added basic use-based wand identification, with zap usage progress persisted through save/load.
- Made wands properly equippable in the `misc` slot and upgraded quickslot behavior so quickslotted wands enter targeting directly for faster SPD-style tool use.
- Rebuilt the alchemy recipe layer so seed-to-potion and stone-to-scroll recipes now use valid item IDs, and updated the alchemy window to operate on real `Recipe` results instead of broken placeholder dictionaries.
- Wired `Alchemize` to actually open `WndAlchemy` anywhere through `EventBus.show_window`, and hooked the Alchemist's Toolkit into crafting so it gains progress from completed recipes.
- Implemented the missing hero `search` action by routing toolbar search through the normal hero action pipeline and calling the existing secret-door/hidden-trap reveal logic, so searching now spends a real turn and can actually discover adjacent secrets without duplicate signal handling.
- Improved search and door parity further: bumping/clicking adjacent impassable terrain now searches instead of failing silently, adjacent doors use the shared `Door` interaction logic, and keyboard `S` now triggers search directly.
- Added explicit search feedback in the main action animation path, so using search now shows a visible status/particle effect on the hero even when no secret is found.
