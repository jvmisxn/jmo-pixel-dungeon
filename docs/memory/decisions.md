# Decisions

## 2026-05-08

- Tags: workflow, memory, documentation
- Decision: Use `docs/memory/` as the canonical low-token memory layer for future work.
- Why: Existing large logs are useful historical references but too expensive to treat as the default context source.
- Consequence: Future sessions should update concise memory files first and consult larger logs only when necessary.

## 2026-05-08

- Tags: architecture, strategy
- Decision: Treat the project as a playable port that still needs hardening before serious framework extraction.
- Why: Core runtime systems are substantial, but persistence and system boundaries are not clean enough yet for safe multi-game branching.
- Consequence: Prefer hardening core contracts before major customization or frameworkization.
