<!--
SYNC IMPACT REPORT
==================
Version change: NEW → 1.0.0
Bump rationale: MAJOR — initial constitution for bauwerksmonitoring project.
  Derived from fibery-skill 1.2.1 template; all principles rewritten for
  Django 5 + DRF + Vue 3 + InfluxDB structural health monitoring platform.
Modified principles: N/A (initial version)
Added sections: All (I–VI)
Removed sections: N/A
Templates requiring updates:
  - .specify/templates/plan-template.md ✅ — generic, no project-specific violations
  - .specify/templates/tasks-template.md ✅ — generic, no project-specific violations
  - .specify/templates/spec-template.md ✅ — generic, no project-specific violations
Deferred items: none
-->

# bauwerksmonitoring Constitution

## Core Principles

### I. No Unnecessary Code

Every function, class, and module MUST exist because it is needed now —
not because it might be useful later.

- Functions MUST be ≤ 80 lines. Split if longer.
- Maximum 4 levels of indentation (5 acceptable inside class methods).
- No speculative abstractions. Three identical patterns is the threshold
  for introducing a shared helper — not two, not one.
- No backwards-compatibility shims for removed code.
- No docstrings on functions that weren't modified or don't need explanation.
- No error handling for scenarios that cannot happen. Trust internal code;
  only validate at system boundaries (user input, external APIs).

### II. Python Type Annotations — Simple Only

Type annotations MUST use Python built-in types only:
`str`, `int`, `float`, `bool`, `list[X]`, `dict[K, V]`, `tuple`.

- NEVER use `Optional[X]` — return an empty/default value (`""`, `[]`, `{}`,
  `0`, `None`) and document the contract in the function signature instead.
- NEVER use `from __future__ import annotations`.
- NEVER import from `typing` for annotations (`List`, `Dict`, `Tuple`, etc.).
  Use built-in generics (`list[str]`, `dict[str, int]`) directly.

### III. No Silent Exception Swallowing

`try/except` blocks are ONLY permitted when a specific, named exception must
be handled (e.g., network errors, user input parsing). They MUST NOT:
- Catch `Exception` broadly and continue silently.
- Log-and-continue in a way that hides failures from the caller.
- Exist solely to return a default value when a simpler guard would do.

The sync worker watch loop is the one approved exception: it catches
`OperationalError` with a 30-second retry, which is explicitly documented.

### IV. Logical Commits — Push After Every Completed Task

After each task (or tightly related group of tasks), a logical git commit
MUST be made with a clear, descriptive message summarising what changed and why.
Every commit MUST be pushed to the remote immediately.

No work accumulates locally across multiple tasks without being committed and
pushed. This keeps progress visible and branches in sync with remote.

Commit messages MUST follow the conventional-commits prefix convention:
`feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, `test:`.

### V. Backend–Frontend Separation of Concerns

The Django/DRF backend MUST remain a pure JSON API — no template rendering,
no business logic in views beyond request/response translation.

- Business logic lives in service functions or management command helpers,
  not in APIView methods.
- Vue 3 components MUST NOT contain business logic — only UI state and API
  calls via `fetch`. Heavy data transformation belongs in `computed` properties
  or composables, not inline in templates.
- CSS MUST use design-system CSS variables (`var(--brand)`, `var(--border)`,
  etc.) defined in `frontend/src/style.css`. Hardcoded hex values are
  a constitution violation except for white (`#fff`) where no token exists.

### VI. Branch Lifecycle Management

A feature branch MUST be merged into `master` and deleted immediately upon
completion — not deferred to the start of the next feature.
Deletion is a two-step atomic action performed right after the merge commit:

```bash
git branch -d BRANCH
git push origin --delete BRANCH
```

Both the local branch AND the remote tracking branch MUST be deleted together.
Leaving either behind is a governance violation.

A branch is considered complete when all tasks in `tasks.md` are checked off
and the feature has been smoke-tested in the browser against the real backend.

## Development Workflow

- **Branch naming**: `NNN-short-description` (auto-assigned by speckit).
  Legacy branches (e.g., `feature/alert-event-db`) use `SPECIFY_FEATURE=NNN-name`.
- **Task execution**: Follow `tasks.md` phase by phase. Do not skip phases.
- **Checkpoint rule**: At each phase checkpoint, run `python manage.py check`
  and verify the relevant UI flow manually. Only commit if clean.
- **Commit discipline**: One logical commit per completed task or phase.
  Push immediately. Messages MUST describe the change and its purpose,
  not just what files were touched.
- **Migrations**: Every model change MUST have a corresponding migration
  committed in the same commit as the model change. Never commit a model
  change without its migration.
- **Merging & cleanup**: Immediately after a feature is complete, merge into
  `master` (`git merge --no-ff`) then delete both local and remote branches.
  Do not defer. Stale merged branches are a governance violation (Principle VI).

## Governance

This constitution supersedes all other development practices for this project.
Amendments require:
1. A clear rationale for the change.
2. An update to this file with a version bump (see versioning below).
3. Propagation to any affected spec, plan, or task templates.

**Versioning policy**:
- MAJOR: A principle is removed or fundamentally redefined in a breaking way.
- MINOR: A new principle or section is added, or existing guidance is
  materially expanded.
- PATCH: Wording clarifications, typo fixes, non-semantic refinements.

All implementation work (PRs, task lists, plans) MUST be verified against
the active principles before merge. Constitution violations require documented
justification in the Complexity Tracking table of the relevant `plan.md`.

**Version**: 1.0.0 | **Ratified**: 2026-04-08 | **Last Amended**: 2026-04-08
