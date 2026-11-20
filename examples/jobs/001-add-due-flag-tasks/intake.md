DECISION: ACCEPT
Risk: low
Surfaces: none

## Summary
- Asks for an optional due date on `tasks add`.
- Small, local change to one function and its CLI flag; easy to revert.
- No UI beyond one new flag; no security surface.

## Scope
In: an optional `--due YYYY-MM-DD` flag on `add`, stored on the task, validated as a date.
Out: reminders, sorting by due date, natural-language dates ("next friday").

## Comment
Accepted as asked: an optional `--due YYYY-MM-DD` on `tasks add`. Reminders and sorting by date are out of scope for this PR.
