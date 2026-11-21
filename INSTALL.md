# Installing the factory (instructions for a coding agent)

A person pointed you at this repository and asked you to install the software
factory into their project. Do the steps below in order, in the project's
root. Stop and ask the person whenever a step says so; otherwise keep going.
At the end, report what you did and anything they must do by hand.

## 1. Check the project

Each of these must hold. If one doesn't, stop and tell the person what's
missing and how to fix it.

- The project is a git repository, you're at its top level, and it has an
  `origin` remote on GitHub.
- `gh auth status` succeeds, and the signed-in account can push to the repo
  and manage its labels (`gh repo view --json viewerPermission` is `ADMIN`,
  `MAINTAIN` or `WRITE`).
- `claude --version` is 2.1.257 or later (the intake agent runs on Fable).
- `python3 --version` is 3.9 or later (the scripts use only the standard
  library) and `bash` is available.
- `git status` is clean, so the install lands as its own commit.
- The default branch (`gh repo view --json defaultBranchRef`) exists on
  `origin`. Note its name for step 4.

## 2. Copy the factory in

Clone this repository somewhere outside the project and run its installer:

```bash
git clone --depth 1 https://github.com/michael-muir/simple-software-factory-v2.git /tmp/software-factory
/tmp/software-factory/install.sh --dry-run "$PWD"
/tmp/software-factory/install.sh "$PWD"
```

If the dry run reports conflicting files, show them to the person and ask
before re-running with `--force`. If the factory is already installed, use
`--upgrade` instead (it keeps `config.json`, `checks.sh`, `backlog.md`,
`repo.md` and `factory/jobs/`).

## 3. Write the project's checks

`factory/checks.sh` is the gate: it runs on every build before any reviewer
reads the code, and again before every merge. Replace its placeholder block
(the lines from `FACTORY-CHECKS-NOT-CONFIGURED` to `exit 1`) with the
project's real commands:

1. Find them. Look at CI workflows (`.github/workflows/`), `AGENTS.md`,
   `CLAUDE.md`, `package.json` scripts, `Makefile`, `pyproject.toml`/`tox.ini`,
   `Cargo.toml`, `go.mod`, and the README. Prefer what CI already runs.
2. Include, where the project has them: dependency install (if a fresh
   worktree needs it), lint, format **check** (never a formatter that
   rewrites files), typecheck, tests, build.
3. Keep it non-interactive and reasonably fast. Don't add checks the project
   doesn't pass today.
4. Run `factory/bin/gate --main` until it prints `GATE: PASS`. It runs your
   `checks.sh` against a clean copy of `origin/<default branch>`. If it fails
   because the project itself is broken on that branch, stop and tell the
   person; the factory can't pass anything until the base is green.

## 4. Configure

Open `factory/config.json` and set:

- `base_branch` to the default branch from step 1.
- `concurrency`: start at `1` unless the person asked for more.
- `merge_method`: `merge`, `squash` or `rebase`, matching what the repo allows
  (`gh repo view --json mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed`).
- `protected_paths`: keep `factory/` and `.claude/`. Add anything else no
  branch should change on its own, such as `.github/workflows/`, if the person
  wants that.

Leave `reviewers` and `prices_usd_per_mtok` alone unless asked.

## 5. Write the repo notes

Write `factory/repo.md`, which every agent reads first, with these headings:

- **Setup**: what a fresh worktree needs before code runs, or "None".
- **Dev server**: the command, and how to pass a port (`$PORT`, `--port`), or "None".
- **Validation**: the same commands as `checks.sh`, for people and agents.
- **Layout**: where the main code, tests and assets live.
- **Conventions**: style, naming, test patterns, commit style.
- **Review focus**: one line each for `code`, `security`, `ux` and `ui` on
  what matters most in *this* project (e.g. "ux: CLI output is parsed by
  scripts; never change existing formats"). This is how the reviewers are
  tailored to the stack without editing their files, so upgrades keep it.

## 6. Set up GitHub

Run `factory/bin/board init`. It checks `gh` and the repo, and creates the
labels `factory`, `factory:needs-info` and `factory:needs-human`. It exits
non-zero and says why if something is still wrong.

Tell the person: only people with triage or write access can add labels, so
the `factory` label is what decides which issues run. If the repo uses branch
protection with required checks, `gh pr merge` waits for them; the factory
escalates a PR it can't merge.

## 7. Commit and report

Stay on the branch the person is on: don't create or check out another
branch. Commit the new and changed files (`.claude/`, `factory/`,
`.gitignore`) there with a one-line message and show the person the diff.
Ask before pushing. The factory's worktrees branch from `origin/<base>`, so
if the current branch isn't the default branch, tell the person the install
must reach the default branch on `origin` before the first job.

Then report, briefly:

- what `checks.sh` runs, and that `gate --main` passes;
- the config you chose;
- how to start: label an issue `factory`, then run `/factory run` in Claude
  Code (or add lines to `factory/backlog.md` and run `/factory next`);
- how to watch: `cd factory && python3 -m http.server 8000`, then open
  `http://localhost:8000/dashboard.html`;
- that the intake agent runs on Fable once per issue, which on some plans
  bills to usage credits; they can change `model:` in
  `.claude/agents/intake.md` to `opus` if they prefer.
