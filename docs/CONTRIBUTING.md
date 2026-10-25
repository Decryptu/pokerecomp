# Contributing

Read [README.md](../README.md) for usage and [AGENTS.md](../AGENTS.md) for agent
rules. Keep changes focused; report unrelated defects separately.

## Repository boundaries

- Never commit cartridges, `.sav` files or extracted sprites, maps, text or
  audio. Keep `roms/.gdignore`. Enable hooks with
  `git config core.hooksPath .githooks`; the commit hook rejects cartridge data,
  and the push hook runs release gates without starting Godot.
- `game/rom/` verifies identity and addressing. Each generation owns its layout,
  importer and text codec. `RomImport` selects the importer; `GameData` is the
  scene-free content API. Unsupported worlds stay `playable: false`.
- Raw byte runs belong in cache blobs via `RomCache.write_payload_map()` or
  `write_section()`, not JSON arrays. Load world sections lazily.
- World and battle models return events; screens own wording and animation.
  Input uses `PokeButton`, never screen-specific key matching.
- Reach autoloads through static `instance()` accessors. Command-line scripts
  compile before the scene tree exists.
- Diagnostics already captures prints, warnings and errors in bug reports.
  Do not add a parallel reporting path.
- Saves and mod contracts: [SAVES.md](SAVES.md), [MODS.md](MODS.md).

## Source parity

Use the pinned [reference sources](REFERENCES.md). Record a non-obvious source
fact beside the implementation with its file/symbol. Do not duplicate it in a
handoff or feature diary. Keep generation-specific formats separate.

Offsets come from matching builds or independently identified bytes, never from
another game's layout. Add a `verify_layout()` check with each new offset.
Audio behavior follows the cartridge driver; register traces from
`tools/render_audio.gd` are the comparison artifact. Manually stepped screens
must advance the audio driver with the same hardware frame clock.

For subsystem rewrites, compare an exact artifact against an independent
implementation over the affected corpus; settle disagreements against pret.

## Verifying

Choose checks by the changed behavior. Default to one affected run:

```bash
python3 tools/test.py --base origin/main
```

Without `--base`, selection compares uncommitted changes to `HEAD`. Pass test
paths explicitly or use `--list` to inspect selection. The selector follows
class/resource consumers; unknown infrastructure, assets and deletions fall
back to the full suite. Dynamic dependencies still require judgment.

| Change | Check |
|---|---|
| Documentation or comments | Review diff; no engine run |
| Font, spacing, color, static wording | Inspect affected view; no new tests or cartridge sweep |
| Behavior or bug fix | Owning tests; at most one uncovered regression case |
| New script/class | Affected run with `--import` |
| Cache format, shared runtime, importer, decoder | Full suite once plus affected cartridge topic/profile |
| Subsystem rewrite | Full suite once plus independent parity evidence |

Stop when relevant checks pass. Commit, push, PR creation and merge do not
invalidate results. Do not repeat unchanged full runs or run blanket cartridge,
story or warning sweeps for routine changes. Broader checks need a concrete risk.

`--full` runs all GUT tests; `GODOT_BIN` selects the engine. Runs default to an
eight-minute cap (`GODOT_CAP`). Results report slow scripts and fail on missing
tests. PR CI selects affected scripts; main checks all, across up to four
isolated runners. Local runs stay serial because fixtures share `user://` paths.

Cartridge checks: call `tools/validate.gd` without arguments to list topics.
Preview, recording and profiling options belong in the owning tool, linked
from the README. Windowed tools require explicit user authorization to interact
with desktop applications. Warning scans, when needed, accept specific paths:

```bash
godot --headless --editor --path . -- --warning-scan game/path.gd
```

## What a test must earn

Before adding a case, identify the behavior, a plausible regression, and why
existing coverage misses it. Bug fixes get at most one new case, failing before
the fix, at the owning layer. Presentation-only changes get none.

Extend the owning test file. Do not duplicate branches, copy implementation
tables into assertions, test private helpers already covered publicly, add
load-only checks for exercised code, or add production hooks solely for tests.
Keep real cartridges and whole-corpus/frame sweeps out of the default suite.

## Code and writing

- Use tabs, practical static types, `snake_case` files/functions/variables and
  `PascalCase` classes/nodes. Edit text scenes directly; never invent `uid://`.
- Extend the existing owner. Delete one-off tools rather than retaining them.
- Document each fact once. Public guides explain usage and contracts; source
  comments explain evidence, units or non-obvious constraints. Names and types
  replace obvious function summaries. No section banners or narrated code.
- Replace outdated text rather than appending corrections. Keep handoffs to
  current blockers and next steps; no completed-task, CI, branch-cleanup or
  release diaries. Git and release notes already retain history.
- A new API needs a short entry in the existing guide, not a tutorial per method.
  Link to the owning declaration for detailed schemas and provider contracts.
- Remove redundant prose when touching an area. Never raise prose budgets just
  to fit an edit; a new generation may justify a reviewed comment allowance.

`tests/unit/test_source_budget.gd` enforces complexity <=20 per function,
comment blocks <=8 lines and the recorded total comment ceiling. Lower the
ceiling after removals. The pre-push and CI release gates check that total and
the documentation ceiling in `tools/release.sh` (README, AGENTS and `docs/`).

## Godot pitfalls

- GUT can skip scripts that fail to parse; the runner checks selected reports.
- New classes need an editor import (`--import`); existing-script edits do not.
- Do not reparse a running script with `CACHE_MODE_IGNORE`. Use `--check-only`
  in a separate process. Defer scene changes initiated by `_ready()`.
- JSON numbers need integer coercion. Closures capture locals by value; avoid
  signal closures retaining their source.
- Disable `_process` when sampling a manually stepped screen across `await`.
- Output tools must reject paths resolving into the project via `PokeToolPath`.
- Integer division is intentional hardware arithmetic. Convert explicitly when
  a floating result is needed. Compare unexplained dev-engine behavior on stable.
