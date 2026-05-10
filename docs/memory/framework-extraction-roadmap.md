# Framework Extraction Roadmap

## Goal

Turn this codebase from:
- a Shattered-PD-shaped game with multiplayer retrofitted into it

into:
- a reusable 2D turn-based adventure/roguelike framework
- with one concrete shipped game built on top of it
- and room for future spin-offs without dragging SPD-specific assumptions everywhere

## Product Direction

The likely framework target is not "generic 2D game engine."

It is closer to:
- shared-grid 2D adventure framework
- turn scheduler
- actor/buff/combat system
- floor/room/level state
- inventory/equipment/content factory
- event/effect/UI adapter layer
- optional online co-op host-authoritative session layer

That is a strong niche. Do not over-generalize past it too early.

## What Should Become Framework vs Game Content

### Framework Core

- actor lifecycle
- turn scheduling
- commands and action resolution
- map/floor state container
- pathing / LOS / ballistics
- buff/status system
- item/equipment interfaces
- save/load contracts
- event stream
- online host/client session and replication contracts
- generic HUD/window hooks

### Game-Specific Layer

- SPD classes/subclasses
- SPD mobs, bosses, quests, NPC dialogue
- SPD item IDs and factories
- SPD room painters and feeling rules
- SPD art/audio/theme
- SPD progression tables and content weights

## Recommended Target Architecture

### Layer 1: Runtime Kernel

Minimal always-on systems:
- `GameRuntime` or equivalent root context
- tick/turn loop
- event bus / event stream
- scene/session lifecycle
- persistence service

This layer should not know about SPD mobs, items, or dungeon chapters.

### Layer 2: Simulation Core

Core rules/data objects:
- `Actor`
- `TurnScheduler`
- `WorldState`
- `LevelState`
- `CommandResolver`
- `EffectResolver`
- `InventoryModel`
- `StatusEffectModel`

This layer should be mostly presentation-agnostic.

### Layer 3: Content Modules

Data + factories:
- hero classes
- mobs
- items
- traps
- plants
- rooms
- biomes/themes

This is where SPD-specific content should live.

### Layer 4: Presentation Adapters

Godot scene/UI/effects bindings:
- `GameScene`
- `HUD`
- `StatusPane`
- sprite spawners
- sound hooks
- popup/status effects

This layer listens to resolved state/events and renders them.

### Layer 5: Online Session Layer

Host-authoritative multiplayer:
- lobby/session
- peer ownership
- command transport
- world/combat event transport
- snapshot sync
- reconnect/resync

This should depend on simulation contracts, not drive them.

## Main Blockers In Current Code

### 1. Autoload gravity

The codebase still strongly depends on:
- `GameManager`
- `TurnManager`
- `EventBus`
- `MessageLog`
- `AudioManager`
- `SceneManager`
- `NetworkManager`

This is convenient for one game, but it makes reuse and testing harder.

### 2. Rule code still talks directly to presentation

Examples:
- gameplay code writing to `MessageLog`
- gameplay code triggering SFX directly
- scene code inferring rule events from state deltas

The framework direction should move toward:
- resolve rule
- emit structured event
- presentation consumes event

### 3. Content IDs are still hardcoded into core flows

There is still a lot of:
- string IDs in logic
- SPD-specific factories inside generic gameplay paths

That needs cleaner content registration if this is going to support multiple games.

### 4. Save/load is broad but not yet "framework clean"

Persistence is much better now, but framework-level persistence should be:
- clearly layered
- stable by contract
- not dependent on scene-specific repair logic

### 5. Multiplayer is proving the architecture limits

The co-op work is useful because it exposes the real seams:
- who owns input
- what is canonical state
- what is event vs snapshot
- what is simulation vs presentation

Those same seams are also the framework seams.

## Recommended Extraction Strategy

Do not extract the framework into a separate repo yet.

First, refactor in-place until the boundaries are real.

### Phase A: Stabilize Contracts In This Repo

Focus:
- command/event paths
- event-first presentation
- reduce direct UI/audio calls from rule code
- keep multiplayer hardening because it pressure-tests the boundaries

Exit criteria:
- most gameplay actions resolve through explicit commands
- most client-visible outcomes have explicit events
- presentation mostly reacts instead of deciding

### Phase B: Introduce Namespaced Core Modules

Start creating framework-shaped folders/modules inside this repo:
- `src/framework/runtime/`
- `src/framework/sim/`
- `src/framework/net/`
- `src/framework/ui/`
- `src/game_spd/content/`

You do not need to move everything at once.

Begin with:
- turn scheduling
- action resolution
- actor/status base classes
- network command contracts

### Phase C: Move SPD Content Behind Interfaces

Examples:
- mob registry instead of direct `MobFactory` assumptions
- item registry instead of generator-only fixed IDs
- biome/room generation profiles instead of hardcoded SPD chapter logic

### Phase D: Build One Small Spin-Off Inside The Repo

Before splitting repos, prove reuse with a second tiny game/module.

Good test:
- same turn/actor/combat framework
- different hero classes
- different item set
- different level-generation theme

If that works cleanly, the framework boundary is real.

### Phase E: Split If It Still Makes Sense

Only after:
- simulation core is stable
- content is modular
- presentation is adapter-style
- at least one second design has proven reuse

Then decide whether to:
- keep monorepo
- split framework + game repos

## Concrete Refactor Priorities

### Highest Value

1. Formalize command types and results
- move more gameplay onto explicit command/result structures

2. Formalize event types
- combat events
- world mutation events
- buff/status events
- floor transition events
- inventory/equipment events

3. Reduce rule-to-log/audio coupling
- replace direct side effects with emitted events where possible

4. Narrow `GameManager`
- separate run/session state from rules state

5. Narrow `TurnManager`
- make scheduler logic less scene-aware and less hero-singleton-shaped

### Next Value

6. Content registries
- mobs
- items
- plants
- traps
- room painters / biome profiles

7. Save/load contracts by layer
- actor state
- world state
- content state
- session/multiplayer state

8. Scene adapters
- `GameScene` as renderer/controller for resolved events
- less direct rules orchestration in scene code

## Multiplayer’s Role In Frameworkization

Multiplayer is not a distraction from framework work.

It is currently one of the best tools for forcing the framework seams to become real.

Why:
- it punishes hidden local assumptions
- it punishes direct UI mutation
- it forces command/event contracts
- it forces clean authority rules

So the correct interpretation is:
- multiplayer hardening and frameworkization are overlapping work
- not two separate tracks

## What A Good Spin-Off Path Looks Like

A future project should be able to choose:
- map generation profile
- content registry
- art/audio theme
- progression rules
- whether co-op is enabled

without rewriting:
- scheduler
- base actor logic
- inventory model
- effect/status framework
- save/load core
- network command layer

## Near-Term Recommendation

Keep doing:
- multiplayer hardening
- event-path cleanup
- command-path cleanup

While starting these framework moves:
- document stable core contracts
- create framework-shaped directories/modules in-place
- move one system at a time behind clearer boundaries

## Best Next Framework Tasks

1. Audit and shrink `GameManager` responsibilities.
2. Define a first-class gameplay event schema in code, not just ad hoc signals.
3. Define command/result structs or dictionaries more formally.
4. Carve `TurnManager` into scheduler logic vs scene/input glue.
5. Start a `framework/` namespace in-tree and move the least SPD-specific pieces first.
