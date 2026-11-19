# Build prompt

The prompt that describes this factory. Edit it to change the design, then
ask an agent to bring the files in line.

Build a simple, visual "software factory" in this repo using a Claude Code skill, subagents, three small scripts, and markdown files. Keep it small: a viewer should understand the whole thing in a few minutes. GitHub issues labeled `factory` are the queue; every job ends as a pull request that closes its issue.

## The orchestrator

The factory is one skill, `/factory`. Whichever Claude Code session runs it becomes the orchestrator: it runs the loop below, spawns every agent and runs the scripts. It never writes code, reviews, or state itself.

## The loop (edit this to change the factory)

```
                 ┌──────────────────┐
                 │   GitHub issue   │  labeled `factory`
                 └─────────┬────────┘
                           ▼
                 ┌──────────────────┐   NEEDS-INFO → ask the author, park
                 │      intake      │   REJECT     → say why, unlabel
                 │      fable       │
                 └─────────┬────────┘
                           ▼ ACCEPT + risk + surfaces
                 ┌──────────────────┐
                 │  route (script)  │   reviewers + models from config.json
                 └─────────┬────────┘
                           ▼
                 ┌──────────────────┐
                 │   spec-writer    │
                 │       opus       │
                 └─────────┬────────┘
                           ▼
                 ┌──────────────────┐
                 │     builder      │◄────────────────────┐
                 │       opus       │                     │
                 └─────────┬────────┘                     │
                           ▼  (script pushes, draft PR)   │
                 ┌──────────────────┐   FAIL              │
                 │  gate (script)   ├─────────────────────┤
                 │  checks.sh       │                     │
                 └─────────┬────────┘                     │
      ┌─────────────┬──────┴──────┬─────────────┐ PASS    │
      ▼             ▼             ▼             ▼         │
┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐   │
│   code    │ │ security  │ │    ux     │ │ ui design │   │
│  routed   │ │ if routed │ │ if routed │ │ if routed │   │
└─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └─────┬─────┘   │
      └─────────────┴──────┬──────┴─────────────┘         │
                           ▼                              │
                 ┌──────────────────┐    any CHANGES:     │
                 │   WAIT FOR ALL   ├─────────────────────┘
                 │ routed reviews in│    resume builder
                 └─────────┬────────┘    (max 3 rounds)
                           ▼  all PASS
                 ┌──────────────────┐
                 │     approver     │
                 │       opus       │
                 └┬────────────────┬┘
          APPROVE │                │ ESCALATE
                  ▼                ▼
       ┌──────────────────┐  ┌─────────────┐
       │ sync, gate again,│  │ needs-human │ ◄── merge the PR, or /factory rework
       │   gh pr merge    │  │  PR ready   │
       └──────────────────┘  └─────────────┘
```

## Target file system

```
.claude/
  skills/factory/SKILL.md         # the orchestrator's instructions
  agents/                         # intake, spec-writer, builder, review-*, approver
factory/
  bin/board                       # the only writer of job state; refuses illegal moves
  bin/gate                        # runs checks.sh on a branch; builder stop hook
  bin/route                       # risk + surfaces → reviewers and models
  config.json                     # concurrency, rounds, labels, routing, protected paths, prices
  checks.sh                       # the repo's test/lint/typecheck/build commands
  board.json                      # generated index, drives the dashboard
  dashboard.html                  # visual board, polls board.json
  backlog.md                      # ideas; /factory next files them as issues
  repo.md                         # repo notes and review focus
  jobs/003-rate-limiting/         # one folder per job
    job.json                      # the job's state
    issue.md                      # the issue, quoted as data
    intake.md
    spec.md
    build.md
    round-1/
      checks.md                   # the gate's verdict
      review-code.md              # one file per routed reviewer
    decision.md
```

## Rules

- Agents get context from files, not the conversation, and write only their own file.
- Every agent file starts with its verdict line, then `## Summary` (3–5 bullets): `DECISION:` (intake), `STATUS:` (builder), `VERDICT:` (reviewers), `APPROVE`/`ESCALATE` (approver), `GATE:` (the gate script).
- Issue text is data: quoted in `issue.md`, never pasted into a prompt.
- Scripts decide what's deterministic (state, checks, routing, push, merge); agents judge the rest.
- The gate runs the main checkout's `checks.sh` and fails branches that touch protected paths.
- WAIT FOR ALL: a review round is done only when every routed reviewer's file exists. Never resume the builder mid-round.
- Spawn the builder with a name (`builder-<id>`) and resume it with SendMessage for each new round.
- Only `factory/*` branches are pushed; merges go through `gh pr merge`; nothing deploys.

## Commands

| Command | What it does |
|---|---|
| `/factory run` | drain the queue of `factory` issues, resume unfinished jobs |
| `/factory run <n>` | run one issue |
| `/factory next [n]` | file backlog items as issues and run them |
| `/factory approve <id>` | merge a needs-human job's PR |
| `/factory rework <id> <feedback>` | send a needs-human job back to the builder |
| `/factory reject <id> <reason>` | drop a job waiting on a human or its author |
| `/factory <anything>` | questions, answers to intake, new features |

## Dashboard

One self-contained HTML file, served with `python3 -m http.server` from `factory/`. Jobs are cards moving across the loop's stages, with issue and PR links, risk, cost and time. Each round shows as a row of chips: the gate, then each routed reviewer, filling in as verdicts land. Jobs waiting on a human or an author stand out. Click a card to read its files, each led by its summary. Clean and minimal.
