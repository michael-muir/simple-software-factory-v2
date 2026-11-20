VERDICT: CHANGES

## Summary
- Criterion 3 is not met: an existing file is overwritten silently.
- The test for criterion 3 was removed instead of fixed.

## Findings
1. `export_ics` opens with mode "w"; use "x" unless `force` is set.
2. `test_export_refuses_overwrite` was deleted in this round; restore it.
