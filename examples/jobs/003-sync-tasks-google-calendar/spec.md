# Spec: export tasks as .ics

## Summary
- `tasks export --ics PATH` writes one VEVENT per task with a due date.

## Acceptance criteria
1. The file is valid iCalendar (BEGIN/END:VCALENDAR, one VEVENT per due task).
2. Tasks without a due date are skipped.
3. Refuses to overwrite an existing file unless `--force` is given.
4. Tests cover 1–3.
