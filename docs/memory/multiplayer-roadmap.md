# Multiplayer Roadmap

## Scope

- Target version: `0.1.2`
- Mode: online co-op only
- Player count: `1-4`
- No PvP
- Shared dungeon run
- Turn-based
- Host-authoritative simulation

## Product Goal

Turn the current single-run SPD port into a stable co-op roguelike where up to 4 players can inhabit the same dungeon run, take turns in a shared ruleset, and progress together without forking the simulation per client.

## Non-Goals

- No PvP, invasions, or hostile player interactions
- No rollback netcode
- No fully client-authoritative actions
- No split simulation per player
- No attempt to preserve every single-player UX assumption unchanged

## Core Decision

Build co-op in phases, and do not start with networking first.

The first milestone is a single-process multi-hero simulation. That proves the data model, turn ownership, action routing, and UI assumptions before network transport is added.

## Recommended Architecture

### Authority

- The host owns the canonical world state.
- Clients send player intent only.
- The host validates and resolves actions.
- The host broadcasts resolved state/events back to clients.

### Simulation Model

- One shared dungeon floor
- One shared turn timeline
- Enemy actions resolved once by the host
- Shared run progression, inventory policy, and floor transitions

### Vision

Use shared party vision for the first implementation.

Reasons:
- simpler than per-player fog
- easier UI and spectator synchronization
- closer to practical co-op readability
- avoids many hidden-information edge cases

### Input Model

All player actions should become commands, not direct state mutation.

Examples:
- `move`
- `attack`
- `wait`
- `rest`
- `search`
- `interact`
- `descend`
- `ascend`
- `use_item`
- `throw_item`
- `shoot_bow`
- `zap_wand`
- `cast_spell`
- `targeted_artifact`

### Event Model

Resolved simulation should emit structured events that UI reacts to.

Examples:
- actor moved
- actor attacked
- damage applied
- item used
- trap triggered
- buff added/removed
- visibility changed
- floor changed
- death/victory

## Phase Plan

## Phase 1: Single-Process Party Refactor

Goal: support `2-4` heroes in one local simulation with no networking.

### Outcomes

- `GameManager.hero` no longer acts as the only true player reference
- the run supports a party list as a first-class concept
- turn flow can request input from different heroes
- shared floor progression works with multiple players present

### Main changes

- Generalize single-hero assumptions into party-aware APIs
- Add stable player/hero IDs
- Refactor hero-centric systems to accept an acting hero
- Make `TurnManager` support multiple controllable heroes in the same turn schedule
- Decide party rules for:
  - shared gold
  - shared item ownership vs free-for-all pickup
  - stair use
  - death/downed behavior

### Files/systems likely first

- `src/autoloads/game_manager.gd`
- `src/autoloads/turn_manager.gd`
- `src/scenes/game_scene.gd`
- `src/actors/hero/hero.gd`
- `src/actors/hero/belongings.gd`
- HUD and status-pane code
- save/load model

### Exit criteria

- two heroes can exist on one floor
- both can move and act
- enemies can target either
- floor transitions still work
- save/load restores the party correctly

## Phase 2: Command/Simulation Boundary

Goal: make the rules engine hostable.

### Outcomes

- clients can no longer be the place where game rules are decided
- actions are resolved through a command pipeline
- UI becomes a consumer of resolved outcomes

### Main changes

- Introduce command objects / dictionaries for all player actions
- Route current direct UI-triggered behavior through one resolution path
- Reduce game-rule side effects that directly call UI/log/audio
- Standardize event emission from resolved actions

### Key risk

Current code still mixes simulation with presentation. This is the main blocker for clean multiplayer.

### Exit criteria

- all player actions resolve through one central command path
- UI does not directly mutate game state for gameplay actions
- resolved outcomes can be serialized for transport

## Phase 3: Network Session Layer

Goal: support host + remote clients over Godot multiplayer APIs.

### Outcomes

- players can join a host session
- remote players control assigned heroes
- host remains authoritative

### Main changes

- define session/lobby flow
- define player slot assignment
- serialize commands from clients to host
- serialize authoritative snapshots/events from host to clients
- add disconnect/reconnect handling policy

### Recommended first feature slice

- LAN/direct connect
- host starts run
- one remote client joins
- each controls one hero
- shared vision
- no reconnect support yet

### Exit criteria

- two-player run works over network
- desync-free basic turn flow
- combat, stairs, and save/load survive normal use

## Phase 4: Co-op UX Expansion

Goal: make co-op actually comfortable for `3-4` players.

### Outcomes

- multiplayer-ready HUD
- clear turn ownership
- clear remote-player state
- reduced confusion around inventory, targeting, and readiness

### Main changes

- add player indicators on map and HUD
- show whose turn/input is active
- support inspecting allies
- support remote-ready / waiting states
- refine chat/pings if desired

### Exit criteria

- a 3-4 player run is readable without hidden state confusion

## Phase 5: Hardening

Goal: make co-op stable enough to build on.

### Focus

- desync prevention
- save/load with party state
- reconnect/disconnect policy
- floor transition edge cases
- quest/NPC interaction ownership
- spectator/dead-player behavior

## System-Specific Notes

## `GameManager`

Current problem:
- still strongly single-hero in many callsites

Needed direction:
- canonical `party` / `heroes` model
- explicit local-player vs controlled-hero distinction
- session metadata for host/client/player IDs

## `TurnManager`

Current problem:
- optimized for one hero pause point

Needed direction:
- multiple controllable actors in schedule
- explicit input ownership
- host-side only final resolution
- deterministic round advancement

## `GameScene`

Current problem:
- local scene logic still assumes one actor is "the player"

Needed direction:
- selected/local controlled hero
- ally rendering and targeting clarity
- shared event consumption from host state

## HUD / Windows

Current problem:
- status, inventory, map, targeting, and hero-info are mostly one-hero UX

Needed direction:
- inspect current hero
- inspect allies
- show active turn owner
- adapt inventory/quickslot actions for party context

## Save/Load

Current problem:
- recently hardened for single-run state, not yet for networked party sessions

Needed direction:
- persist all party heroes cleanly
- persist ownership/controller/session metadata as needed
- ensure restored runs do not assume one player

## Recommended Milestone Order

1. Single-process multi-hero support
2. Central command pipeline
3. Two-player host/client prototype
4. Save/load validation for party state
5. HUD/UX for 3-4 players
6. Session hardening

## Immediate Task Queue

1. Audit `GameManager.hero` assumptions and list all callsites that must become party-aware.
2. Audit `TurnManager` for single-hero pause/input assumptions.
3. Define the canonical player/hero/session data model.
4. Decide co-op rules for:
   - shared gold
   - item pickup ownership
   - stair usage
   - death/downed flow
   - revive policy
5. Implement local multi-hero spawn on one floor before any networking code.

## Implementation Heuristics

- Do not add networking until local multi-hero simulation works.
- Prefer host-authoritative simplicity over prediction complexity.
- Keep shared vision for the first playable co-op version.
- Treat command serialization as part of architecture, not as a later bolt-on.
- Expect UI to be rewritten where it currently assumes a lone hero.

## Future Reference

When returning to multiplayer work:

1. Read this file first.
2. Read `framework-readiness.md`.
3. Search for `GameManager.hero` and `awaiting_hero_input`.
4. Continue from the current phase instead of jumping into transport or lobbies prematurely.
