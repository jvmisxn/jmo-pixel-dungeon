# Tests

Lightweight headless test harness. No external addon (no GUT) — just a
`SceneTree` runner Godot can execute with `--headless`.

## Run locally

Requires Godot 4.5 on PATH:

```bash
godot --headless --path . -s res://tests/run_tests.gd
```

Exit code `0` = all checks passed, `1` = at least one failed. CI (`.github/workflows/ci.yml`) runs exactly this.

## Add a test

1. Create `tests/cases/test_<thing>.gd`:

   ```gdscript
   extends RefCounted

   func run(t: Object) -> void:
       t.check(2 + 2 == 4, "math works")
   ```

2. Register it in the `CASES` array at the top of `tests/run_tests.gd`.

`t.check(cond, msg)` records one assertion; a false `cond` fails the suite.

## What's covered today

- **test_compile** — every autoload script loads as valid GDScript (catches
  truncation / parse breakage in the runtime spine).
- **test_event_bus** — the EventBus signal contract other systems connect to
  stays intact.
- **test_headless_save_descend_reload** — starts a run, descends to depth 2 with
  a deterministic smoke level, saves, reloads, and checks broad hero/level/
  inventory state survived.

## Good next targets (from the audit)

- Pure-geometry tests for `Ballistica` / `ShadowCaster` / `Pathfinder` (S22 —
  much of combat/AI/wands rides on them and they have zero coverage).
- Narrow save contracts for `Hero` / `Level` / scheduler details as those
  contracts are fixed (S01/S03/S04 — persistence is the top-risk area).
- Generator drop-table invariants (S12).
