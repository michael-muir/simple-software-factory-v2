# Sample jobs

Five jobs from a scripted run on a small made-up `tasks` CLI, for trying the
dashboard without running the factory. To see them:

```sh
mkdir -p factory/jobs && cp -r examples/jobs/* factory/jobs/
factory/bin/board index
cd factory && python3 -m http.server 8000   # open http://localhost:8000/dashboard.html
```

How they were made: the real `factory/bin/board`, `gate` and `route` scripts
drove each job through the pipeline against a real git origin, so `job.json`,
the history, the gate files and the routing are genuine script output. The
agents' files (intake, spec, build, reviews, decision) were written by hand,
GitHub was the test suite's stand-in (`tests/fake_gh.py`), and the costs come
from stand-in transcripts with plausible token counts. Paths were rewritten to
`/home/you/code/tasks-cli`. Times are short because nothing waited on a model.

| job | what it shows |
|---|---|
| `001-add-due-flag-tasks` | Low risk, no surfaces: one code reviewer on Haiku. Gate and review pass in round 1; merged through its PR. |
| `002-show-tasks-table-colors` | A `ui` surface adds the UX and UI reviewers. UX asks for changes in round 1; round 2 passes; merged. |
| `003-sync-tasks-google-calendar` | Intake cuts "two-way calendar sync" down to an `.ics` export. The round 1 gate fails because the builder edited `factory/config.json` (a protected path). Code review asks for changes twice, rounds run out, and the job goes to a human. |
| `004-make-it-faster` | Too vague: intake asks the author a question and the job waits. |
| `005-upload-everyones-task-lists` | A data-exfiltration request with an embedded "ignore previous instructions": rejected at intake. |
