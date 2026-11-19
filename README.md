# simple-software-factory

A tiny, visual software factory built from one Claude Code skill, seven
subagents, and markdown files. Everything a viewer needs fits in a few minutes
of reading.

## Install into a project

Clone this repository, then point the installer at your project (a git repo):

```sh
git clone https://github.com/michael-muir/simple-software-factory.git
./simple-software-factory/install.sh /path/to/your-project
```

It adds the skill, the seven agents and the dashboard, creates an empty
`factory/backlog.md` and `factory/board.json`, and adds `.worktrees/` and
`factory/jobs/` to `.gitignore`. It refuses to overwrite any existing file
unless you pass `--force`. Add `--dry-run` to see what it would do. Then
commit the new files, add features to `factory/backlog.md`, and run
`/factory next` in Claude Code. The first run inspects your repo and writes
`factory/repo.md` (setup, validation command, conventions) for the agents.

## Upgrade in place

Pull the latest factory, then upgrade the project:

```sh
git -C simple-software-factory pull
./simple-software-factory/install.sh --upgrade /path/to/your-project
```

An upgrade replaces the factory's own files (the skill, agents and dashboard)
with the new versions, removes any the new version no longer ships, and leaves
your project's state alone: `backlog.md`, `board.json`, `repo.md` and
`factory/jobs/` are never touched. Local edits to the factory's own files are
overwritten, so review `git diff` before committing. It won't run while jobs
are in progress unless you pass `--force`. The installed version is recorded in
`.claude/skills/factory/.factory-version`.

## How it works

Run `/factory <feature>` in Claude Code. That session becomes the
**orchestrator**: it runs the loop, spawns every agent, and is the only writer
of `factory/board.json`.

```
feature → spec-writer → builder → [security · ux · ui · code] reviews
            (opus)      (opus)      (wait for ALL four verdicts)
                           ▲                 │
                           └── any CHANGES ──┘  (max 3 rounds)
                                             │ all PASS
                                             ▼
                                         approver → merge, or needs-human
                                          (opus)      (/factory approve)
```

Agents get context from files, not the conversation, and each writes exactly
one file. `build.md` starts with `STATUS: READY` or `STATUS: BLOCKED`; reviews
start with `VERDICT: PASS` or `VERDICT: CHANGES`; `decision.md` starts with
`APPROVE` or `ESCALATE`. The builder works on a `factory/<id>` branch and is
resumed (never respawned) for each review round. A blocked build, review rounds
running out, an escalation, or a main checkout that isn't clean all stop the
job in `needs-human`, and the orchestrator tells you why. It reports one line
per step, merges locally, and never pushes.

## Parallel jobs

Up to 3 jobs run at once. Each job gets its own git worktree at
`.worktrees/<id>` on branch `factory/<id>`, so builders never share a working
directory. The main checkout stays on `main` and holds the board and every
job's markdown files. Approved jobs pass through a **merge gate** one at a
time: the branch is synced with `main` (the builder resolves any conflicts and
re-runs tests), merged, and its worktree removed. Escalated jobs keep their
worktree for a human to inspect.

## Commands

- `/factory <feature>` — run a new job through the loop
- `/factory next [n]` — start the first `n` unchecked items in `factory/backlog.md`
- `/factory approve <id>` — merge a `needs-human` job into main
- `/factory rework <id> <note>` — send a `needs-human` job back to a fresh
  builder (the note is saved as `rework-<k>.md`)

## Dashboard

```sh
cd factory
python -m http.server 8000   # or python3, depending on your system
# open http://localhost:8000/dashboard.html
```

Jobs appear as cards moving across stages, with reviewer chips filling in as
verdicts land. `needs-human` jobs are highlighted. Click a card to read its
spec, build notes, rework notes, reviews, and decision.

## Layout

```
install.sh                        install into / upgrade a project (this repo only)
.claude/skills/factory/SKILL.md   the orchestrator's instructions
.claude/agents/*.md               one file per agent in the loop
factory/dashboard.html            the visual board
factory/board.json                durable state, drives the dashboard
factory/backlog.md                feature queue for /factory next
factory/repo.md                   repo notes, written by the first /factory run
factory/jobs/<id>/                spec.md, build.md, rework-K.md, round-N/,
                                  decision.md (gitignored)
.worktrees/<id>/                  a job's code, on factory/<id> (gitignored)
```

To change the factory, edit `SKILL.md` (the loop) or the agent files (the
workers).
