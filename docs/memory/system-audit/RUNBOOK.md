# System Audit Loop — RUNBOOK (one iteration per cron fire)

You are an isolated agent. Do exactly ONE system this run, then stop. Fresh context —
everything you need is here and in the repo. Repo root:
`<repo-root>`.

## Golden rules (non-negotiable)

- **No truncation, ever.** Read every file you touch IN FULL. Use targeted `Edit`, never
  rewrite a healthy file wholesale. This repo has broken from partial writes before.
- **Audit code changes are gated.** Only *mechanically-safe* fixes may be auto-applied, and
  only on a branch behind a PR — never on `main`, never merged automatically.
- **Verify every edit** with `gdparse` (below). If it doesn't parse, revert and backlog it.
- **Never auto-edit a file listed in `TRUNCATED_FILES.txt`** — too fragile. Backlog instead.
- High signal only. Rank findings by value. Don't pad reports with nitpicks.

## Setup

```bash
export PATH="$HOME/Library/Python/3.9/bin:$PATH"   # gdparse/gdlint live here
cd <repo-root>
git checkout main && git pull --ff-only 2>/dev/null || true
```

`gdparse <file.gd>` exits 0 and prints nothing if the file parses; non-zero + error if not.
That is your syntax/truncation gate (there is no Godot engine on this machine).

## Step 1 — Pick the system

Open `docs/memory/system-audit/ledger.md`. Take the system at the **Pointer** line
(the highest `pending` row). If every row is `done`, post to Discord
`channel:1525381784773070988`: "🎉 System audit loop complete — all systems evaluated.
This job can be disabled." Then STOP.

## Step 2 — Audit it (the real work)

Read that system's files in full. Judge it on three axes and gather concrete, cited findings:

- **Improvements** — correctness, SPD fidelity, robustness, save/load safety, coupling.
- **Optimizations** — perf, allocations, redundant work, autoload-dependency reduction.
- **Additions** — missing SPD features, framework-extraction hooks, tests.

Research where it sharpens a finding: web-search Godot 4.5 GDScript best practices and/or
original Shattered PD behavior (1–3 searches max). Reason against SPD's patterns for parity.

Write the report to `docs/memory/system-audit/reports/<ID>-<slug>.md` using the template in
`docs/memory/system-audit/README.md`. Tag each finding P0 (correctness/data-loss), P1 (high
value), P2 (nice), P3 (optional). Most-valuable first. Cite `file:line` where you can.

## Step 3 — File the backlog

Append every P0/P1 finding (and any P2/P3 you do NOT auto-fix) to
`docs/memory/backlog.md` under "## System Audit Findings", each one line, tagged
`[P?][audit:<ID>]`, most valuable first.

## Step 4 — Auto-fix (only the safe ones)

A finding is **auto-fixable** only if ALL hold:
- It is P2 or P3 AND purely mechanical with **no behavioral change** (e.g. deletion of code
  proven unreferenced by a repo-wide `grep`/`rg`, dead-branch removal, comment/typo fixes).
- The target file is **not** in `TRUNCATED_FILES.txt`.
- You can state, in one line, why it cannot change runtime behavior.

Anything requiring judgment, touching persistence/combat/generation logic, or that you're
even slightly unsure about → leave it in the backlog for approval. **Max 2 auto-fixes per run.**

For each auto-fixable finding:
```bash
git checkout -B audit/autofix    # long-lived fix branch, first run creates it
```
- Apply with targeted `Edit`. Re-read the last ~15 lines of the file to confirm a clean ending.
- `gdparse <file>` — must pass. If it fails: `git checkout -- <file>`, move the item to the
  backlog, and do not commit it.
- `git add <file> && git commit -m "audit(<ID>): <short fix>"`
Then push and open/refresh the PR (never merge):
```bash
git push -u origin audit/autofix 2>/dev/null || git push origin audit/autofix
gh pr view audit/autofix >/dev/null 2>&1 \
  || gh pr create --base main --head audit/autofix \
       --title "Audit auto-fixes (mechanically-safe)" \
       --body "Automated, verified-safe cleanups from the system-audit loop. Review before merge."
```
Finally return to main for the doc commit: `git checkout main`.

## Step 5 — Update the ledger

In `ledger.md`: set this system's Status to `done`, add `[report](reports/<ID>-<slug>.md)`
plus a one-line verdict, advance the **Pointer** to the next `pending` ID, and bump the
"Completed: N / 37" tally.

## Step 6 — Commit the audit trail to main

```bash
git add docs/memory/system-audit docs/memory/backlog.md
git commit -m "audit(<ID>): evaluate <system name>"
git push origin main 2>/dev/null || true
```
(Docs go to main; only code fixes go to the branch/PR.)

## Step 7 — Report to Discord

Post a short update to `channel:1525381784773070988` (#pixel-dungeon). Keep it tight:
- **System** audited + **verdict**.
- Top 2–3 findings (with priority tags).
- Auto-fixes opened this run + PR link, or "no safe auto-fixes."
- Progress: **N / 37** systems done. Next up: `<next system>`.
No tables. Plain Discord bullets. Then STOP — one system per run.
