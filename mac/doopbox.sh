#!/usr/bin/env bash
# Runs the open-source Doop locally on Node with its built-in database (PGlite). The Mac app calls this; it also
# works by hand:  doopbox.sh doctor | setup | start | stop | check | update | backup | backup-now | backup-dir
#
# Everything lives in ~/Library/Application Support/DoopBox (override: DOOPBOX_HOME):
#   app/        official Doop clone at a release tag, never modified (its data/ holds the database and uploads)
#   backups/    backups on this Mac (default): copies of app/data
#   backup-dir  optional: a folder (iCloud Drive, a NAS…) to back up to *instead*, one .tar.gz per backup
#   .env        generated secret          .version  release tag currently built
#   server.pid  server.log                status    current step, shown by the app's loading screen
set -euo pipefail

HOME_DIR="${DOOPBOX_HOME:-$HOME/Library/Application Support/DoopBox}"
PORT="${DOOPBOX_PORT:-4300}"
REPO=https://github.com/kgoedecke/doop.git
BUN="bun@1.3.10"   # the version Doop pins in package.json
MIN_NODE=22
KEEP_BACKUPS=7

# Exit codes the app understands (besides 0 and 1)
E_UPDATE=10   # check: a newer release exists
E_NODE=20     # Node.js missing or too old
E_GIT=21      # git missing

APP="$HOME_DIR/app"
PIDFILE="$HOME_DIR/server.pid"
LOG="$HOME_DIR/server.log"
STATUS="$HOME_DIR/status"
EXTRA_FILE="$HOME_DIR/backup-dir"
mkdir -p "$HOME_DIR"

# ---------------------------------------------------------------- environment

# A Finder-launched app has a bare PATH; add the usual places for git and mise-managed Node.
export PATH="$HOME/.local/share/mise/shims:/opt/homebrew/bin:/usr/local/bin:$PATH"

# It also can't see Node from nvm, fnm, Volta, asdf… (they live in shell startup files). If none was found, ask the
# user's login shell where its node is. Interactive (-i) so rc files load; perl's alarm stops a slow shell hanging us.
if ! command -v node >/dev/null 2>&1; then
  shell_node=$(perl -e 'alarm 8; exec @ARGV' "${SHELL:-/bin/zsh}" -lic 'echo "__NODE__$(command -v node)"' 2>/dev/null </dev/null \
    | sed -n 's/^.*__NODE__//p' | tail -1 || true)
  [ -x "$shell_node" ] && export PATH="$(dirname "$shell_node"):$PATH"
fi

# ---------------------------------------------------------------- helpers

healthy() { curl -sf "http://localhost:$PORT/healthz" >/dev/null; }
say() { echo "$(date '+%F %T') $*"; }
version() { cat "$HOME_DIR/.version" 2>/dev/null || echo none; }

# The current step for the app's loading screen. Only a process that wrote a step removes it,
# so a quick `check` can't erase a running setup's progress.
progress() { printf '%s' "$1" > "$STATUS"; trap 'rm -f "$STATUS"' EXIT; }

# ---------------------------------------------------------------- requirements

# One line per tool for the app's first-run checklist: "key<TAB>ok|missing|old<TAB>detail".
# Exit 0 when everything required (Node.js, git) is there; Chrome is optional (frame screenshots).
doctor() {
  local missing=0 v major
  if command -v node >/dev/null 2>&1; then
    v=$(node -v 2>/dev/null | sed 's/^v//'); major=${v%%.*}
    if [ "${major:-0}" -ge "$MIN_NODE" ] 2>/dev/null; then printf 'node\tok\tv%s\n' "$v"
    else printf 'node\told\tv%s found, %s or newer is needed\n' "$v" "$MIN_NODE"; missing=1; fi
  else printf 'node\tmissing\tNot found\n'; missing=1; fi
  if v=$(git --version 2>/dev/null); then printf 'git\tok\t%s\n' "${v#git version }"
  else printf 'git\tmissing\tNot found\n'; missing=1; fi
  if [ -d "/Applications/Google Chrome.app" ]; then printf 'chrome\tok\tInstalled\n'
  else printf 'chrome\tmissing\tNot found\n'; fi
  exit $missing
}

# ---------------------------------------------------------------- install & build

latest_tag() {
  git -C "$APP" fetch --quiet --tags origin
  git -C "$APP" tag -l 'v*' --sort=-v:refname | head -1
}

# Check out a release tag and build it. dist/ is untracked, so a checkout alone does not change what runs.
build_tag() {
  local tag=$1
  progress "Downloading Doop $tag"
  git -C "$APP" fetch --quiet --depth 1 origin tag "$tag"
  git -C "$APP" -c advice.detachedHead=false checkout --quiet "$tag"
  progress "Installing dependencies"
  (cd "$APP" && npx -y "$BUN" install --frozen-lockfile)
  progress "Building Doop"
  (cd "$APP" && npx -y "$BUN" run build)
  echo "$tag" > "$HOME_DIR/.version"
}

setup() {
  # Read the whole report first: under pipefail, `grep -q` quitting early would make doctor die of SIGPIPE.
  local report latest
  report=$(doctor 2>/dev/null || true)
  grep -q '^node	ok' <<<"$report" || { echo "Node.js $MIN_NODE or newer is required" >&2; exit $E_NODE; }
  # On a Mac without developer tools, running git is what makes macOS offer to install them.
  git --version >/dev/null 2>&1 || { echo "git is required" >&2; exit $E_GIT; }
  if [ ! -d "$APP/.git" ]; then
    progress "Downloading Doop"
    git clone --quiet --depth 1 "$REPO" "$APP"
  fi
  latest=$(latest_tag)
  [ -n "$latest" ] || { echo "No release tag found" >&2; exit 1; }
  if [ "$(version)" != "$latest" ] || [ ! -d "$APP/dist" ]; then
    build_tag "$latest"
  fi
  if [ ! -f "$HOME_DIR/.env" ]; then
    (umask 077; echo "BETTER_AUTH_SECRET=$(openssl rand -hex 32)" > "$HOME_DIR/.env")
  fi
}

# ---------------------------------------------------------------- server

# start [timeout-seconds]
start() {
  local timeout=${1:-120}
  healthy && exit 0
  # Only after a first-time setup does the loading screen mention the step; a normal launch stays quiet.
  [ -d "$APP/dist" ] && [ -f "$HOME_DIR/.env" ] || { setup; progress "Starting Doop"; }
  set -a; . "$HOME_DIR/.env"; set +a
  local chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  [ -x "$chrome" ] && export CHROME_PATH="$chrome"
  export NODE_ENV=production PORT="$PORT" BETTER_AUTH_URL="http://localhost:$PORT"
  cd "$APP"
  nohup node_modules/.bin/tsx server/index.ts >>"$LOG" 2>&1 &
  echo $! > "$PIDFILE"
  for _ in $(seq 1 "$timeout"); do
    healthy && exit 0
    kill -0 "$(cat "$PIDFILE")" 2>/dev/null || break
    sleep 1
  done
  exit 1
}

stop() {
  [ -f "$PIDFILE" ] || exit 0
  local pid; pid=$(cat "$PIDFILE")
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid"
    # Let PGlite flush before giving up on it.
    for _ in $(seq 1 20); do kill -0 "$pid" 2>/dev/null || break; sleep 0.5; done
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" || true
  fi
  rm -f "$PIDFILE"
}

running() { [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }

# ---------------------------------------------------------------- backups
# PGlite is a plain folder and unsafe to copy while the server has it open, so every backup happens with the
# server stopped: on quit (once a day), before an update, or with backup-now (stop, back up, start).

extra_dir() { [ -f "$EXTRA_FILE" ] && cat "$EXTRA_FILE" || true; }

# prune_old <dir> <name-prefix>: keep the newest KEEP_BACKUPS, ordered by the timestamp in the name.
# Never lets a failure (a cloud folder that went offline, say) stop the caller.
prune_old() {
  { ls -1d "$1"/"$2"* | sort -t- -k3,3 -k4,4 \
      | awk -v keep="$KEEP_BACKUPS" '{ a[NR] = $0 } END { for (i = 1; i <= NR - keep; i++) print a[i] }' \
      | while read -r old; do rm -rf "$old"; done; } 2>/dev/null || true
}

# One .tar.gz per backup suits cloud folders better than thousands of small files.
backup_to_folder() {
  local dest=$1 name=$2
  tar -czf "$dest/$name.part" -C "$APP/data" . && mv "$dest/$name.part" "$dest/$name" \
    || { rm -f "$dest/$name.part" 2>/dev/null; return 1; }
}

backup_local() {
  local day=$1 force=$2 dest
  mkdir -p "$HOME_DIR/backups"
  if [ "$force" != force ] && ls -d "$HOME_DIR"/backups/data-*-"$day"-* >/dev/null 2>&1; then return 0; fi
  dest="$HOME_DIR/backups/data-$(version)-$day-$(date +%H%M%S)"
  cp -R "$APP/data" "$dest"
  prune_old "$HOME_DIR/backups" data-
  echo "$dest"
}

# make_backup [force]: one per day unless forced. Goes to the chosen folder; to this Mac when none is chosen, or
# when the chosen one is missing or offline (a backup is never skipped for that). Prints the new backup's path.
make_backup() {
  local force=${1:-} day extra name
  [ -d "$APP/data" ] || return 0
  day=$(date +%Y%m%d)
  extra=$(extra_dir)
  if [ -n "$extra" ] && [ -d "$extra" ]; then
    if [ "$force" != force ] && ls -d "$extra"/doopbox-*-"$day"-* >/dev/null 2>&1; then return 0; fi
    name="doopbox-$(version)-$day-$(date +%H%M%S).tar.gz"
    if backup_to_folder "$extra" "$name"; then
      prune_old "$extra" doopbox-
      echo "$extra/$name"
      return 0
    fi
  fi
  backup_local "$day" "$force"
}

# The app runs this right after `stop` when it quits.
backup() {
  running && { echo "Stop the server first" >&2; exit 1; }
  make_backup >/dev/null
}

backup_now() {
  (stop)
  make_backup force
  (start)
}

# backup-dir             print the chosen folder (empty: this Mac)
# backup-dir <path>      back up to that folder instead;  backup-dir --clear  back to this Mac
backup_dir() {
  case "${1:-}" in
    "") extra_dir ;;
    --clear) rm -f "$EXTRA_FILE" ;;
    *) [ -d "$1" ] || { echo "Not a folder: $1" >&2; exit 1; }; printf '%s' "$1" > "$EXTRA_FILE" ;;
  esac
}

# ---------------------------------------------------------------- Doop updates (release tags only)

# Prints the newest release tag. Exit 0 = up to date, E_UPDATE = newer release, 1 = couldn't check.
check() {
  [ -d "$APP/.git" ] || { echo "Not set up yet" >&2; exit 1; }
  local latest
  latest=$(latest_tag) || exit 1
  [ -n "$latest" ] || exit 1
  echo "$latest"
  [ "$latest" = "$(version)" ] && exit 0
  exit $E_UPDATE
}

# Back up, switch to the newest release, restart, health-check; on failure put the old version and its data back.
# Doop's database migrations run at boot and can't be undone, so a rollback restores the data too — from a copy
# kept on this Mac (a cloud backup folder may not have synced yet), removed afterwards.
update() {
  local current latest rollback="$HOME_DIR/rollback"
  current=$(version)
  latest=$(latest_tag)
  [ -n "$latest" ] || { say "No release tag found"; exit 1; }
  if [ "$latest" = "$current" ]; then say "Already on $current"; exit 0; fi

  say "Updating $current → $latest"
  (stop)
  rm -rf "$rollback"
  [ -d "$APP/data" ] && cp -R "$APP/data" "$rollback"
  make_backup force >/dev/null || true

  if build_tag "$latest" && (start "${DOOPBOX_HEALTH_TIMEOUT:-120}"); then
    rm -rf "$rollback"
    say "Updated to $latest"
    exit 0
  fi

  say "$latest failed — rolling back to $current"
  (stop)
  if [ "$current" != none ]; then
    if [ -d "$rollback" ]; then rm -rf "$APP/data" && cp -R "$rollback" "$APP/data"; fi
    build_tag "$current"
    (start) || true
  fi
  rm -rf "$rollback"
  exit 1
}

# ----------------------------------------------------------------

case "${1:-}" in
  doctor) doctor ;;
  setup) setup ;;
  start) start ;;
  stop) stop ;;
  check) check ;;
  update) update ;;
  backup) backup ;;
  backup-now) backup_now ;;
  backup-dir) shift; backup_dir "$@" ;;
  *) echo "usage: $0 doctor|setup|start|stop|check|update|backup|backup-now|backup-dir" >&2; exit 2 ;;
esac
