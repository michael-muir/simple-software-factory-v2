DECISION: ACCEPT
Risk: medium
Surfaces: ui

## Summary
- Asks for a readable table view of `tasks list`, overdue in red.
- Changes the output people read every day, so it's a UI surface.
- Medium risk: scripts may parse the current output.

## Scope
In: a table for `tasks list` on a terminal; overdue tasks in red; plain output when piped.
Out: themes, configurable columns.

## Comment
Accepted: `tasks list` becomes a table with overdue tasks in red, and keeps plain output when piped so scripts don't break.
