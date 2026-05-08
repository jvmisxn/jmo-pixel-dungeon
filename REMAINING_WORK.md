# Remaining Work — Shattered Pixel Dungeon (Godot)

## 1. What's Implemented (All 6 Phases)

### Phase 1: Dungeon Generation (43 files)
Complete procedural level generation with region-specific room types, corridor algorithms, trap placement, door/key logic, special rooms (shops, alchemy labs, wells, gardens, vaults), and boss arenas for all five regions.

### Phase 2: Actors & Combat (62 files)
Full actor/character system with hero (5 classes, command pattern, XP/leveling, hunger), 26 mob types across 5 regions with unique AI behaviors, 5 bosses with multi-phase fights, 19 buff/debuff types, 7 blob/gas types, and complete combat formulas matching SPD.

### Phase 3: Items & Inventory (27 files, ~10,000 lines)
Complete item hierarchy: 25 melee weapons (5 tiers), 12 thrown weapons, spirit bow, 5 armor tiers, 14 potions, 14 scrolls, 11 rings, 13 wands, 12 artifacts, 7 food types, 4 bag types, 4 key types, 10 bomb types, 11 runestones, 9 spells. Enchantment/glyph systems, alchemy recipes, loot generation with weighted tables.

### Phase 4: Rendering & Visuals (14 files)
Procedural 16x16 pixel art for all terrain types (5 region palettes), character sprites (hero classes + 26 mob shapes), item sprites (12 categories), three-state fog of war, smooth camera with zoom/shake, effect system (damage numbers, projectiles, particles, lightning, screen flash).

### Phase 5: UI & Menus (24 files)
Full HUD (status pane, toolbar, game log, minimap), inventory window with filters/sorting, item detail/action windows, hero stats, game menu, shop, alchemy, journal. Title screen, hero select, loading transitions, death screen, victory surface scene, rankings.

### Phase 6: Integration & Polish
Plants system (8 plant types with seed-to-plant growth), NPC quest chain (Ghost, Wandmaker, Imp, Blacksmith), audio framework (procedural SFX, ambient loops), save/load system, balance reference file, web export configuration.


## 2. Known Gaps

### Gameplay — Missing Features
- ~~**Subclass abilities**: All 10 subclasses implemented with full buff mechanics~~ ✓
- ~~**Piranha mobs**: Water-based enemies with depth scaling~~ ✓
- ~~**Mimics**: Disguised enemies with item sprite swap on reveal~~ ✓
- ~~**Animated statues**: Mini-boss statues with enchanted weapon drops~~ ✓
- ~~**Golden statues**: Rare variant with damage reduction and upgraded weapons~~ ✓

### Items — Missing Interactions
- ~~**Enchantment/glyph visual effects**: All 9 enchantments and 12 glyphs now trigger visual effects~~ ✓
- ~~**Scroll of Transmutation**: Full item selection UI with category filters and transmutation logic~~ ✓
- **Cursed item interactions**: Some cursed wand/ring effects are simplified compared to SPD

### NPCs — Incomplete
- **Full NPC dialogue trees**: Current NPC quests have functional but minimal dialogue
- ~~**Ambitious Imp ring shop UI**: Implemented via WndQuestReward~~ ✓
- ~~**Blacksmith reforge UI**: Full reforge window with Keep/Consume slots and upgrade transfer~~ ✓
- ~~**Sad Ghost reward selection**: Implemented via WndQuestReward with weapon/armor choice~~ ✓

### Meta Systems
- ~~**Badge/achievement system**: 26 badges implemented with persistent storage (BadgesManager autoload)~~ ✓
- **Tutorial/guidebook content**: Journal guide tab exists but has placeholder text only
- **Localization support**: All strings are hardcoded English; no i18n framework
- **Accessibility features**: No screen reader support, no colorblind mode, no remappable controls

### Audio & Art
- **Sound effect variety**: Currently procedural tones only; no attack/impact/spell/ambient SFX variety
- **Proper music tracks**: No background music; ambient loop is procedural drone
- **Asset pipeline for real pixel art**: All graphics are procedural; no framework for loading sprite sheets or texture atlases from PNG files


## 3. Multiplayer Next Steps

### Current Architecture Readiness
The codebase was designed with multiplayer in mind from Phase 2 onward:
- **Command pattern**: Hero actions go through `submit_action({type, ...})` -> `execute_action()` -> `spend_turn()`, making it straightforward to serialize and replicate commands
- **Heroes array**: `GameManager.heroes[]` holds all active heroes alongside the legacy `GameManager.hero` reference
- **Peer ID**: `Hero` has a `peer_id` property for associating heroes with network peers
- **Turn system**: `TurnManager` already processes a queue of actors; multiple heroes slot in naturally
- **Clean state/render split**: Game logic is in pure GDScript classes (RefCounted/Node), rendering is separate in `src/sprites/` and `src/scenes/`

### What Needs to Change

1. **Network transport layer**: Add a `NetworkManager` autoload wrapping Godot's `MultiplayerPeer` (WebRTC for browser, ENet for desktop). Handle connection, disconnection, reconnection.

2. **Authoritative server model** (recommended):
   - One player hosts (or a dedicated lightweight server runs the game)
   - Server owns all game state: level, mobs, items, fog of war
   - Clients send action commands; server validates and executes them
   - Server broadcasts state deltas (mob moved, damage dealt, item dropped) to all clients
   - Each client only receives fog-of-war-filtered updates (no omniscient cheating)

3. **Turn system for multiple players**:
   - Option A — **Sequential turns**: Players take turns in order. Simple but slow with 3+ players.
   - Option B — **Simultaneous input**: All players submit actions, server resolves in priority order (move > attack > wait). Better pacing.
   - Option C — **Real-time with pause**: Free movement, any player can pause. Most complex.
   - **Recommended**: Start with Option A (sequential), migrate to Option B once stable.

4. **State synchronization**:
   - Serialize level terrain, mob positions/HP, item heaps as initial state on join
   - Delta updates: only send what changed each turn (mob_moved, damage_taken, item_picked_up)
   - Use Godot's `@rpc` annotations on GameManager/TurnManager methods

5. **UI changes**:
   - Multiple health bars in the status pane (one per hero)
   - "Waiting for player..." indicator during other players' turns
   - Shared vs split inventory: recommend shared loot with "dibs" system
   - Chat/emote system for player communication
   - Spectator mode for dead players (follow surviving heroes)

### Suggested Implementation Order
1. `NetworkManager` autoload with host/join/lobby flow
2. RPC wrappers on `hero.submit_action()` and `TurnManager`
3. Sequential turn system with "waiting" UI
4. State sync: initial level state on join, per-turn deltas
5. Fog of war per-hero (each player sees only their hero's FOV)
6. Death/spectator handling
7. Simultaneous turn resolution (Option B)
8. WebRTC support for browser-to-browser play

### Network Considerations
- **Latency**: Turn-based games are latency-tolerant. 200ms RTT is fine.
- **Bandwidth**: Delta state updates are small (~100 bytes/turn). Level init is ~32KB.
- **Cheating**: Authoritative server prevents most cheats. Never trust client damage/HP values.
- **Reconnection**: Save full game state; reconnecting player receives current snapshot.
- **WebRTC for web**: Godot 4.5 supports WebRTC multiplayer, enabling browser-to-browser without a relay server for LAN play. For internet play, a TURN server may be needed.


## 4. Web Export Instructions

### Prerequisites
- Godot 4.5 with Web export templates installed
- (In Godot Editor: Editor > Manage Export Templates > Download)

### Build Steps
1. Open the project in Godot 4.5
2. Go to Project > Export
3. The "Web" preset should already be configured (see `export_presets.cfg`)
4. Click "Export Project..."
5. Choose output directory (default: `build/web/`)
6. Uncheck "Export with Debug" for production builds
7. Click "Save"

### Output Files
- `index.html` — main page
- `index.js` — Godot engine loader
- `index.wasm` — compiled game
- `index.pck` — packed game resources
- `index.worker.js` — web worker (if threads enabled)
- `index.audio.worklet.js` — audio worklet

### Deployment
- Upload all files in `build/web/` to any static web host (GitHub Pages, Netlify, itch.io, etc.)
- The server must serve `.wasm` files with `Content-Type: application/wasm`
- For itch.io: zip the `build/web/` folder contents and upload as HTML game
- **IMPORTANT**: The server must support `SharedArrayBuffer` headers if using threads:
  ```
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
  ```
- If your host doesn't support those headers, the non-threaded export (default) works everywhere

### Project Settings for Web (already configured)
- Viewport: 1280x720, stretch mode "canvas_items", aspect "expand"
- Renderer: GL Compatibility (required for web)
- Texture filter: Nearest (pixel art)
- Audio mix rate: 44100 Hz
- 2D pixel snapping enabled


## 5. Testing Recommendations

### Critical Path (Must Test)
- **Full game loop**: Title > Hero Select > Loading > Play through 5+ floors > Die > Death screen > Rankings > Title
- **Each hero class**: Verify starting stats, starting items, and class-specific perks display correctly
- **Combat math**: Verify damage rolls fall within expected ranges (see `src/balance.gd` reference table)
- **Boss fights**: Test Goo (depth 5) and Tengu (depth 10) at minimum — multi-phase transitions, special attacks
- **Inventory management**: Equip/unequip weapons and armor, use potions and scrolls, verify stat changes
- **Save/Load**: Save mid-run, quit, reload — verify hero position, HP, inventory, floor state all persist

### Region-Specific
- **Sewers (1-5)**: Rat/Gnoll/Crab spawns, grass trampling, water terrain, Goo boss arena
- **Prison (6-10)**: Skeleton explosions, Thief stealing, Guard chain pull, Tengu arena
- **Caves (11-15)**: Bat vampiric healing, Brute enrage, DM-300 pylons
- **City (16-20)**: Warlock ranged attacks, Monk disarm, Golem teleport, Dwarf King phases
- **Halls (21-26)**: Succubus charm+teleport, Evil Eye beam, Yog-Dzewa fist spawns

### Systems
- **Hunger**: Verify drain rate (~45 turns per ration), starvation damage at 0
- **Fog of war**: Three states (unseen/visited/visible), mobs only visible in FOV
- **Alchemy**: Test seed+seed=potion recipes, stone crafting
- **Traps**: Visible/hidden/triggered states, each trap type effect
- **Plants**: Seed planting, growth, trampling effects (8 plant types)
- **NPC quests**: Ghost quest item fetch, Wandmaker quest completion, Blacksmith quest
- **Shop**: Buy/sell prices, gold deduction, inventory transfer

### Performance (Web-Specific)
- **Initial load time**: Should be under 5 seconds on broadband
- **Frame rate**: Target 60 FPS with full dungeon rendered + fog of war + effects
- **Memory**: Monitor for leaks during extended play (100+ turns)
- **Audio**: Verify procedural audio plays without crackling or latency in browser
- **Input**: Test both mouse click-to-move and keyboard (arrows, numpad, vi keys, hotkeys)
- **Mobile browser**: Touch input may need additional work; current design is keyboard+mouse

### Edge Cases
- **Dying on a boss floor**: Verify death screen shows correct cause, stats save to rankings
- **Full inventory**: Picking up items when backpack is full
- **Cursed equipment**: Cannot unequip, scroll of remove curse works
- **Stacking items**: Potions/scrolls/thrown weapons merge correctly
- **Floor transitions**: Ascending/descending preserves level state, mob positions reset appropriately
