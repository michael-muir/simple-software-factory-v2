#!/usr/bin/env bash
# Install the software factory into an existing project, or upgrade it in place.
#
#   ./install.sh <project-dir>              install
#   ./install.sh --upgrade <project-dir>    upgrade an existing install
#
# Options:
#   --dry-run   show what would change, change nothing
#   --force     install over conflicting files / upgrade while jobs are running
#   -h, --help  show this help
#
# Run it from a clone of this repository. The factory's own files (the skill,
# its agents and the dashboard) are managed by this script and overwritten on
# upgrade. The project's own state (factory/backlog.md, factory/board.json,
# factory/repo.md and factory/jobs/) is created if missing and never touched
# after that.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
MANIFEST=".claude/skills/factory/.factory-manifest"
VERSION_FILE=".claude/skills/factory/.factory-version"
SEED_FILES=("factory/backlog.md" "factory/board.json")
IGNORE_LINES=(".worktrees/" "factory/jobs/")

mode="install"; dry=0; force=0; target=""

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
die() { echo "error: $*" >&2; exit 1; }
say() { echo "$*"; }
act() { if [ "$dry" -eq 1 ]; then say "  (dry run) $*"; else say "  $*"; fi; }

while [ $# -gt 0 ]; do
  case "$1" in
    --upgrade) mode="upgrade" ;;
    --dry-run) dry=1 ;;
    --force) force=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option: $1 (see --help)" ;;
    *) [ -z "$target" ] || die "more than one project directory given"; target="$1" ;;
  esac
  shift
done
[ -n "$target" ] || { usage; exit 1; }

# --- checks -----------------------------------------------------------------
[ -f "$SRC/.claude/skills/factory/SKILL.md" ] \
  || die "run this from a clone of the factory repository ($SRC has no factory skill)"
[ -d "$target" ] || die "project directory not found: $target"
TARGET="$(cd "$target" && pwd -P)"
[ "$TARGET" != "$SRC" ] || die "that is the factory repository itself"
git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || die "$TARGET is not a git repository (the factory needs git worktrees)"
# The orchestrator works from the repo root, so the factory must live there.
[ -z "$(git -C "$TARGET" rev-parse --show-prefix)" ] \
  || die "$TARGET is inside a git repository; point at its top level: $(git -C "$TARGET" rev-parse --show-toplevel)"

# Files this script owns, relative to the repo root.
managed_files() {
  (
    cd "$SRC"
    find .claude/skills/factory -type f ! -name '.factory-*'
    find .claude/agents -maxdepth 1 -type f -name '*.md'
    echo factory/dashboard.html
  ) | sed 's#^\./##' | sort
}
# (a read loop, not mapfile: macOS still ships bash 3.2)
FILES=()
while IFS= read -r f; do FILES+=("$f"); done < <(managed_files)

installed=0
[ -f "$TARGET/.claude/skills/factory/SKILL.md" ] && installed=1

if [ "$mode" = "install" ]; then
  [ "$installed" -eq 0 ] \
    || die "the factory is already installed in $TARGET; use --upgrade"
  conflicts=()
  for f in "${FILES[@]}"; do
    if [ -e "$TARGET/$f" ] && ! cmp -s "$SRC/$f" "$TARGET/$f"; then
      conflicts+=("$f")
    fi
  done
  if [ "${#conflicts[@]}" -gt 0 ] && [ "$force" -eq 0 ]; then
    echo "error: these files already exist in the project and would be overwritten:" >&2
    printf '  %s\n' "${conflicts[@]}" >&2
    echo "Rename or remove them, or re-run with --force to overwrite." >&2
    exit 1
  fi
else
  [ "$installed" -eq 1 ] \
    || die "the factory is not installed in $TARGET; run without --upgrade first"
  board="$TARGET/factory/board.json"
  if [ -f "$board" ] && grep -Eq '"stage": *"(spec|build|review|approval|merge)"' "$board"; then
    if [ "$force" -eq 0 ]; then
      die "factory/board.json has jobs in progress; finish them first, or re-run with --force"
    fi
    say "warning: jobs are in progress; their agents will pick up the new instructions"
  fi
fi

version="unknown"
if git -C "$SRC" rev-parse --short HEAD >/dev/null 2>&1; then
  version="$(git -C "$SRC" rev-parse --short HEAD)"
  [ -z "$(git -C "$SRC" status --porcelain 2>/dev/null)" ] || version="$version-dirty"
fi
old_version="none"
[ -f "$TARGET/$VERSION_FILE" ] && old_version="$(head -1 "$TARGET/$VERSION_FILE")"

if [ "$mode" = "install" ]; then
  say "Installing the software factory ($version) into $TARGET"
else
  say "Upgrading the software factory in $TARGET ($old_version -> $version)"
fi

added=0; updated=0; same=0; removed=0

# --- remove files a previous version installed but this one no longer has ---
if [ "$mode" = "upgrade" ] && [ -f "$TARGET/$MANIFEST" ]; then
  while IFS= read -r old; do
    [ -n "$old" ] || continue
    case "$old" in /*|*..*) continue ;; esac   # only plain relative paths
    keep=0
    for f in "${FILES[@]}"; do [ "$f" = "$old" ] && keep=1 && break; done
    if [ "$keep" -eq 0 ] && [ -f "$TARGET/$old" ]; then
      act "removed   $old"; removed=$((removed + 1))
      [ "$dry" -eq 1 ] || rm -f "$TARGET/$old"
    fi
  done < "$TARGET/$MANIFEST"
fi

# --- copy managed files -----------------------------------------------------
for f in "${FILES[@]}"; do
  if [ ! -e "$TARGET/$f" ]; then
    act "added     $f"; added=$((added + 1))
  elif cmp -s "$SRC/$f" "$TARGET/$f"; then
    same=$((same + 1)); continue
  else
    act "updated   $f"; updated=$((updated + 1))
  fi
  if [ "$dry" -eq 0 ]; then
    mkdir -p "$(dirname "$TARGET/$f")"
    cp "$SRC/$f" "$TARGET/$f"
  fi
done

# --- seed project state (only if missing) ------------------------------------
for f in "${SEED_FILES[@]}"; do
  if [ ! -e "$TARGET/$f" ]; then
    act "created   $f"
    if [ "$dry" -eq 0 ]; then
      mkdir -p "$(dirname "$TARGET/$f")"
      cp "$SRC/$f" "$TARGET/$f"
    fi
  fi
done

# --- .gitignore ---------------------------------------------------------------
gi="$TARGET/.gitignore"
for line in "${IGNORE_LINES[@]}"; do
  if [ ! -f "$gi" ] || ! grep -qxF "$line" "$gi"; then
    act "ignored   $line (.gitignore)"
    if [ "$dry" -eq 0 ]; then
      # make sure the file ends with a newline before appending
      if [ -s "$gi" ] && [ -n "$(tail -c1 "$gi")" ]; then echo >> "$gi"; fi
      echo "$line" >> "$gi"
    fi
  fi
done

# --- record what was installed ----------------------------------------------
if [ "$dry" -eq 0 ]; then
  mkdir -p "$(dirname "$TARGET/$MANIFEST")"
  printf '%s\n' "${FILES[@]}" > "$TARGET/$MANIFEST"
  printf '%s\n%s\n' "$version" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$TARGET/$VERSION_FILE"
fi

summary="Done: $added added, $updated updated, $same unchanged"
[ "$removed" -eq 0 ] || summary="$summary, $removed removed"
say "$summary."
if [ "$dry" -eq 1 ]; then
  say "Dry run: nothing was changed."
elif [ "$mode" = "install" ]; then
  cat <<EOF

Next steps, in $TARGET:
  1. Review and commit the new files (.claude/, factory/, .gitignore).
  2. Add features to factory/backlog.md, then run /factory next in Claude Code
     (or /factory <feature>). The first run inspects the repo and writes
     factory/repo.md for the agents.
  3. Watch it: cd factory && python -m http.server 8000, then open
     http://localhost:8000/dashboard.html
EOF
else
  say "Review the changes with git diff in $TARGET, then commit them."
fi
