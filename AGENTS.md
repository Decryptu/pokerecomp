# Working in this repository

Follow [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md), especially its verification
policy and "What a test must earn". This policy supersedes older local checklists
that prescribe blanket validation.

- Default to `python3 tools/test.py --base origin/main`; inspect with `--list`.
- For font size, spacing, colors and static wording, inspect the affected view.
  Do not add tests, run the full suite or sweep cartridges for these changes.
- For behavior changes, extend the existing owning test only for an uncovered
  failure mode. A bug fix needs at most one new regression case, not a matrix.
- Run relevant checks once. Repeat only after a change invalidates the result
  or a failure needs investigation. CI is not a reason to repeat local checks.
- Full-suite and cartridge sweeps require the scope described in the contributor
  policy. Use affected topics/profiles rather than `validate -- all` by default.
- Keep one test file per subject and one assertion layer per behavior. Remove
  redundant cases when editing tests. Never add test-only production hooks.
- Keep unrelated defects out of the task. Report them instead of expanding scope.
- Do not control browsers or desktop apps without the user's explicit request.
- Do not end responses with offers for additional work.

- Keep docs to usage, contracts and current work. No task/CI/release diaries.
- State facts once; link to the owner. Do not add a tutorial for each API.
- Comment only non-obvious constraints, units or source evidence. Delete obvious
  summaries and duplicate prose in the area changed; lower budgets after removals.
