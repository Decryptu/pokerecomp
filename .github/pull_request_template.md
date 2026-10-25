## What this changes

<!-- Concrete problem and resulting behavior. Keep unrelated work out. -->

## Source references

<!-- For cartridge behavior: pinned pret path and symbol. Otherwise omit. -->

## Verification

<!-- State what ran and its result. Choose checks from docs/CONTRIBUTING.md#verifying.
Use tools/test.py for affected tests. Presentation-only changes need visual inspection,
not new tests. Do not repeat the full suite or run every cartridge topic by default.
For new tests: name the uncovered failure mode. Explain broad validation when needed. -->

## Checklist

- [ ] No ROM-derived, generated, cache or local-only file is staged
- [ ] `git diff --cached --check` is clean
- [ ] Docs updated if a contract changed
