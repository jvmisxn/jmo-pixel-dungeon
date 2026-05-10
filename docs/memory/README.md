# Working Memory System

This folder is the repo's lightweight, low-token memory layer for future work.

It exists to answer three questions quickly:

1. What is true about the codebase right now?
2. What decisions have already been made?
3. What did we learn that should change how future work is done?

## Design Goals

- Keep notes short enough to re-read in minutes.
- Store only durable context, not full transcripts.
- Make search cheap with plain markdown plus `rg`.
- Separate current working context from long historical audits.

## Legacy Sources

These larger files already contain substantial prior work, much of it from Claude-agent sessions:

- `docs/history/AUDIT_LOG.md`
- `docs/history/FIX_LOG.md`
- `docs/history/PROGRESS.md`
- `docs/history/CRITICAL_FIXES.md`
- `docs/history/REMAINING_WORK.md`
- `docs/history/INDEX.md`
- `docs/history/SUMMARY.md`

Treat them as historical deep references.
Do not use them as the default first read unless the concise memory files are insufficient.

## Files

- `active-context.md`
  - Current state, near-term focus, constraints, and open risks.
- `architecture-map.md`
  - Stable map of major systems and where they live.
- `decisions.md`
  - Architectural and workflow decisions that should not be re-litigated every session.
- `lessons.md`
  - Repeated mistakes, pitfalls, and heuristics learned while working on the repo.
- `change-log.md`
  - Session-level summaries of meaningful changes, with references to files or systems.
- `backlog.md`
  - Short list of known future work worth revisiting.
- `archive-backlog.md`
  - Condensed unresolved work mined from the large historical logs.
- `system-summaries.md`
  - Short system-level takeaways derived from prior audits and current reading.
- `session-checklist.md`
  - Minimal workflow for using this memory layer consistently.
- `persistence-notes.md`
  - Focused reminder and heuristics for save/load-sensitive work.
- `framework-readiness.md`
  - Short note on what still separates the playable port from a reusable framework.
- `spd-fidelity-notes.md`
  - Short note on remaining parity-oriented work against original SPD.
- `multiplayer-roadmap.md`
  - Durable implementation plan for host-authoritative co-op multiplayer up to 4 players.

## Update Rules

- Prefer appending a short entry over writing a long retrospective.
- Record decisions only when they affect future implementation choices.
- Record lessons only when they would prevent repeat mistakes.
- Record changes at the level of systems or outcomes, not every tiny edit.
- If a note becomes stale, edit it in place instead of layering contradictions.

## Suggested Workflow

Before work:

1. Read `active-context.md`.
2. Search `docs/memory/` for the feature or system name.
3. Read focused topic notes if the task matches them.
4. Only then consult `docs/history/` if needed.

After work:

1. Update `change-log.md` with a short summary.
2. Update `active-context.md` if priorities or constraints changed.
3. Add to `decisions.md` or `lessons.md` only if the insight is durable.

## Search

Quick search:

```powershell
.\scripts\search_memory.ps1 -Query "save load"
```

Search with legacy docs included:

```powershell
.\scripts\search_memory.ps1 -Query "boss floor serialization" -IncludeLegacyDocs
```

## Entry Format

Use compact entries:

```md
## 2026-05-08

- Tags: save-load, architecture
- Summary: Base Level and Hero save/load contracts are incomplete.
- Impact: Treat persistence as unstable until hero/level/mob serialization is hardened.
```
