# Spec: table output for tasks list

## Summary
- A table with title and due columns; overdue rows in red.
- Plain, uncolored output when stdout isn't a terminal.

## Acceptance criteria
1. On a TTY, `tasks list` prints a table with Title and Due columns.
2. Overdue tasks are red; others use the default color.
3. When piped, output is plain text with no escape codes.
4. Tests cover 1–3.
