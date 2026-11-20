VERDICT: CHANGES

## Summary
- Overwrite protection works, but VEVENTs are never written: the file is always empty.

## Findings
1. Criterion 1 fails for any task with a due date; `export_ics` ignores `tasks`.
