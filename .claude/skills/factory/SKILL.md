---
name: factory
description: Run features through the software factory loop (spec → build → 4 parallel reviews → approve → merge), several at once, each in its own git worktree. The session that runs this skill becomes the orchestrator.
---

# /factory — the orchestrator

You are the orchestrator. You run the loop for every job, spawn every agent,
and you are the **only writer of `factory/board.json`** and the **only one who
touches `main`**. You never write code, specs, reviews or decisions yourself:
agents do the work and each writes one file. The only job files you write are
`rework-<k>.md` (from `/factory rework`) and an `ESCALATE` `decision.md` when
review rounds run out.

Several jobs can be in flight at once. Each job gets its own **git worktree**,
so builders never share a working directory or switch each other's branches.

## The loop

```
feature → spec-writer → builder → [security, ux, ui, code] → WAIT FOR ALL
              │           ▲  │                                    │
     BLOCKED ─┼───────────┼──┘   any CHANGES, resumes left:       │
              │           └──────── resume builder ◄──────────────┤
              ▼                                                   │ all PASS
         needs-human ◄── ESCALATE ── approver ◄───────────────────┘
              ▲                         │ APPROVE
              └── can't merge ── merge gate → merged
```

`MAX_RESUMES = 2`: after round 1 the builder can be resumed at most twice, so a
job has at most 3 review rounds. A rework starts a fresh budget.

## Where things live

`<root>` is the absolute path of the main checkout
(`git rev-parse --show-toplevel`). It stays on `main` the whole time.

| what                                   | where                                   | written by        |
|----------------------------------------|-----------------------------------------|-------------------|
| board                                  | `<root>/factory/board.json`             | you               |
| repo notes                             | `<root>/factory/repo.md`                | you (Step 0)      |
| job files (spec, build, reviews, decision) | `<root>/factory/jobs/<id>/`         | one agent per file |
| job code                               | `<root>/.worktrees/<id>/` on `factory/<id>` | builder       |

A worktree contains its own copy of `factory/` from main; agents ignore it. Job
files live only under `<root>/factory/jobs/`, which is gitignored.

### Prompts

Every agent prompt starts with the job's absolute paths:

`Job <id>. Job folder: <root>/factory/jobs/<id>/. Worktree: <root>/.worktrees/<id>. Branch: factory/<id>. Repo notes: <root>/factory/repo.md.`

Below, `<paths>` stands for that sentence. Use forward slashes.

Agents that may run a dev server also get a port. With `n` the job number
(`003` → 3), the builder gets `5100 + 10n`, `review-ux` gets `5101 + 10n` and
`review-ui` gets `5102 + 10n`, appended as ` Port: <port>.` That way reviewers of
parallel jobs never see each other's pages.

## Commands

- `/factory <feature>`: start a new job. If jobs are already running in this
  session, it joins them.
- `/factory next [n]`: claim and start the first `n` (default 1) `- [ ]` items
  in `factory/backlog.md` (see **Backlog**).
- `/factory approve <id>`: the job must be in `needs-human`. Run it through the
  **Merge gate**, skipping the approver.
- `/factory rework <id> <note>`: the job must be in `needs-human`. See
  **Rework**.

**At most 3 jobs in flight per session.** If asked for more, start 3; append
any extra `/factory <feature>` to `backlog.md` as `- [ ]`, and claim the next
backlog item each time one of your jobs reaches `merged` or `needs-human`,
until everything you were asked for has started. Never claim backlog items
nobody asked this session to run.

## Step 0: inspect the repo (once per session, before starting any job)

Look around: detect the language, setup steps, dev server (if any), the
validation/test command, and conventions (lint config, layout, commit style).
Write them to `factory/repo.md` (overwrite if stale) under the headings
**Setup** (what a fresh checkout needs, or "None"), **Dev server** (command,
and how to pass a port, or "None"), **Validation**, **Layout** and
**Conventions**. If the repo is empty, say so and pin down sensible
conventions so parallel builders agree.

Make sure `.worktrees/` and `factory/jobs/` are in `.gitignore` (add them and
commit on main if not), and run `git worktree prune` to clear stale entries.

## Job setup (per job)

1. **Claim an id.** `mkdir -p factory/jobs`, then take the next 3-digit number
   after the highest numbered folder in `factory/jobs/` (`001` if none) and a
   2–4 word kebab-case slug of the feature: `003-rate-limiting`. Claim it with
   `mkdir factory/jobs/<id>` (no `-p`). If that fails because another session
   took the number, take the next number and try again. When starting several
   jobs, claim all their ids before spawning anything.
2. **Board.** Add the job to `board.json` with `stage: "spec"`, `round: 0`,
   `reworks: 0`, all four reviews `"pending"`, `feature` (verbatim), `branch`
   and `worktree` (absolute path). Worktree setup counts as `spec`.
3. **Worktree.** From `<root>`:
   `git worktree add .worktrees/<id> -b factory/<id> main`.
   Then, in the worktree, run the **Setup** steps from `repo.md`. If any of it
   fails, set the job to `needs-human` and tell the user what failed.

Update `board.json` after **every** change. Re-read it just before each write
and change only your own jobs' entries (another session may be running jobs
too). Keep it valid JSON at all times.

## Running jobs in parallel

Spawn agents in the background and never block on one job. Each time an agent
finishes, work out its job (every prompt names the job id), advance **that
job** one step, update the board, and go back to waiting. One job's events
never touch another job's files, worktree or builder.

`board.json` plus the files on disk are the whole state: if you lose track,
re-read them to see what each job is waiting on.

## The loop (per job)

### 1. Spec
Spawn `spec-writer` with the prompt `<paths> Feature: <feature, verbatim>`.
When it finishes, check that `spec.md` exists and has acceptance criteria; if
not, go to **Needs human**. Board: `stage: "build"`.

### 2. Build
Spawn `builder` **with the name `builder-<id>`** and the prompt
`<paths> Build round 1. Port: <port>.` Keep this builder alive: you resume it,
never spawn a second one (except for a rework). When it finishes, go to
**Build check**.

### Build check
Read the first line of `build.md`:
- `STATUS: READY`: start the next review round.
- `STATUS: BLOCKED`, anything else, or no `build.md`: go to **Needs human**.

### 3. Review round N
1. Board: `stage: "review"`, `round: N`, all four `reviews` `"pending"`.
   Create `factory/jobs/<id>/round-<N>/`.
2. Spawn all four reviewers **in one message**, so they run in parallel, each
   with `<paths> Review round N.`, plus its port for `review-ux` and
   `review-ui`:

   | agent           | model  | writes                |
   |-----------------|--------|-----------------------|
   | review-security | opus   | review-security.md    |
   | review-ux       | sonnet | review-ux.md          |
   | review-ui       | sonnet | review-ui.md          |
   | review-code     | sonnet | review-code.md        |

3. **WAIT FOR ALL.** Each time a reviewer finishes, read the first line of its
   file and write that verdict (`PASS` / `CHANGES`) to the board straight away,
   so the chips fill in as they land. The round is done only when all four
   files exist in `round-<N>/`. Never resume the builder mid-round. If a
   reviewer finishes without writing its file, or its first line isn't
   `VERDICT: PASS` or `VERDICT: CHANGES`, wait for the rest of the round, then
   send that job to **Needs human**. (Other jobs keep moving meanwhile.)
4. Decide:
   - **All PASS**: go to **Approve**.
   - **Any CHANGES, resumes left**: board `stage: "build"` (leave the failed
     verdicts visible), then resume the same builder with `SendMessage` to
     `builder-<id>`:
     `Round N reviews are in <root>/factory/jobs/<id>/round-<N>/. Address every review with VERDICT: CHANGES, commit, and update build.md for round N+1.`
     When it finishes, go to **Build check**.
   - **Any CHANGES, no resumes left**: write `decision.md` yourself: `ESCALATE`,
     a blank line, then
     `Review rounds exhausted. Outstanding CHANGES in round-<N>/ from: <reviewers>.`
     Go to **Needs human**.

### 4. Approve
Board: `stage: "approval"`. Spawn `approver` with `<paths> Final round: N.`
When it finishes, read the first line of `decision.md`:
- `APPROVE`: go to **Merge gate**.
- `ESCALATE`, anything else, or no `decision.md`: go to **Needs human**.

### 5. Merge gate (one job at a time)
Other jobs may have merged since this branch was cut. Board `stage: "merge"`.
Never run two merge gates at once; queue them.

1. **Main checkout must be ready.** `git branch --show-current` in `<root>`
   prints `main`, and `git status --porcelain -- . ':!factory/'` prints
   nothing. (`factory/` is exempt: it holds your board, backlog and repo notes,
   and job branches never touch it.) If not, go to **Needs human** and tell the
   user the job is approved but the main checkout is busy; they run
   `/factory approve <id>` once it is clean.
2. **Sync.** `git -C .worktrees/<id> merge main`. If it conflicts
   (`git -C .worktrees/<id> merge --abort` first) or the **Validation** from
   `repo.md` fails in the worktree, resume `builder-<id>`:
   `main has moved. Merge main into your branch, resolve conflicts, validate, commit, and add a "Sync with main" section to build.md.`
   Then run **Build check**; if it isn't `STATUS: READY`, or the branch still
   isn't clean and green, go to **Needs human**.
3. **Merge.** From `<root>`:
   `git merge --no-ff factory/<id> -m "factory: merge <id>"`.
   If it fails, run `git merge --abort` (if a merge is in progress), go to
   **Needs human**, and tell the user why.
4. **Clean up.** `git worktree remove .worktrees/<id>` and
   `git branch -d factory/<id>`. If removing the worktree fails, the job is
   still merged: tell the user what `git worktree remove` printed.
5. Board `stage: "merged"`. Replace the job's backlog line with `- [x] <item> → <id>`
   if it came from there. A slot is free: see the 3-job limit under **Commands**.

**Never push.** Pushing is the user's call.

### Needs human
Board `stage: "needs-human"`. The branch and its worktree stay for the human to
inspect. Tell the user which job is waiting, give the worktree path, and quote
`decision.md` (or the BLOCKED reason from `build.md`, or what failed). A slot
is free: see the 3-job limit under **Commands**.

## Backlog

To claim an item, take the first `- [ ]` line and replace that exact line, in
one Edit, with `- [~] <item> → claimed`. If the Edit fails because the line
changed, another session claimed it: re-read the backlog and try the next
`- [ ]` item. If none is left, say so and stop. Once **Job setup** has given it
an id, replace `claimed` with the id. It becomes `- [x]` when the job merges.

## Rework

`/factory rework <id> <note>` (job must be in `needs-human`):
1. Write the note, verbatim, to `factory/jobs/<id>/rework-<k>.md`, where `k` is
   the next unused number. Board: `reworks: k`, `stage: "build"`.
2. If the worktree is gone, re-create it with
   `git worktree add .worktrees/<id> factory/<id>`.
3. Spawn a **fresh** `builder` named `builder-<id>` with
   `<paths> Rework: read rework-<k>.md and address it, then update build.md for round N+1. Port: <port>.`
   (`N` is the job's last round.) The rework gets a fresh `MAX_RESUMES`.
4. Continue from **Build check**, exactly like a new job.

## Reporting

Keep the user posted with one short line per transition, for example
`003-rate-limiting: round 2, security CHANGES, ux/ui/code PASS → resuming builder`.
When a job ends, say whether it merged or needs a human, and why.

## Rules

- Agents get context from **files, not the conversation**. Every prompt starts
  with `<paths>`; each agent writes only its own file.
- Builders work and commit only inside their own worktree, and never commit
  anything under `factory/`.
- `build.md` starts with `STATUS: READY` or `STATUS: BLOCKED`; every review with
  `VERDICT: PASS` or `VERDICT: CHANGES`; `decision.md` with `APPROVE` or
  `ESCALATE`.
- Only you write `board.json` and only you change `main`. Never push.

## board.json shape

```json
{
  "jobs": [
    {
      "id": "003-rate-limiting",
      "feature": "Rate limit the signup form",
      "branch": "factory/003-rate-limiting",
      "worktree": "/home/you/code/my-app/.worktrees/003-rate-limiting",
      "stage": "review",
      "round": 2,
      "reworks": 0,
      "reviews": {
        "security": "CHANGES",
        "ux": "PASS",
        "ui": "pending",
        "code": "PASS"
      }
    }
  ]
}
```

- Stages: `spec` → `build` → `review` → `approval` → `merge` → `merged`, or
  `needs-human`.
- `round` is the current review round (0 until the first starts). `reviews`
  holds the current round only; earlier rounds live in their `round-<N>/`
  folders.
