# Spec: --due flag for tasks add

## Summary
- `add()` takes an optional `due` date; the CLI exposes it as `--due`.
- Invalid dates fail with a clear message and exit code 2.

## Goal
Let people record when a task is due, so later features can sort and remind.

## Scope
In: `add(title, due=None)`, `--due` parsing and validation. Out: reminders, sorting, display changes.

## Decisions
- ISO dates only (YYYY-MM-DD), parsed with `datetime.date.fromisoformat`.

## Acceptance criteria
1. `add("x", due="2026-12-01")` stores `due` as that date.
2. `add("x")` still works and stores no due date.
3. An invalid date raises `ValueError` naming the bad value.
4. Tests cover 1–3.
