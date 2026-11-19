DECISION: ACCEPT
Risk: high
Surfaces: security

## Summary
- Two-way calendar sync needs OAuth, stored tokens and a network client: too big for one PR.
- Cut to a first slice: export tasks with due dates as an .ics file any calendar can import.
- Writes files from user input, so security review applies; risk high because of the file path.

## Scope
In: `tasks export --ics PATH` writing due tasks as VEVENTs.
Out: Google/Outlook APIs, OAuth, two-way sync, recurring events.

## Comment
This is bigger than one change, so the factory will build a first step: `tasks export --ics PATH`, which writes your tasks with due dates to a calendar file you can import into Google Calendar or Outlook. Live two-way sync is out of scope for now.
