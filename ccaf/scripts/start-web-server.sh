#!/usr/bin/env bash
# start-web-server.sh — Start (or reuse) the CCAF exam web server.
#
# Usage:
#   start-web-server.sh --port PORT --plugin-root PATH
#
# Steps:
#   1. Generate a timestamped exam ID.
#   2. Export the current exam pair (~/.claude/ccaf-exam.local.{md,answers.md})
#      to ~/Documents/CCAF Exams/<EXAM_ID>.json via server.py (export mode).
#   3. Check if the server is already running on PORT.  If not, start it.
#   4. Open the browser at http://localhost:PORT/?exam=<EXAM_ID>.
#   5. Print the URL so the skill can relay it to the user.
set -eo pipefail

# ── Parse args ────────────────────────────────────────────────────────────────
PORT=8765
PLUGIN_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)        PORT="$2";        shift 2 ;;
    --plugin-root) PLUGIN_ROOT="$2"; shift 2 ;;
    *) echo "start-web-server: unknown flag $1" >&2; exit 1 ;;
  esac
done

[[ -n "$PLUGIN_ROOT" ]] || { echo "start-web-server: --plugin-root is required" >&2; exit 1; }

SERVER_PY="$PLUGIN_ROOT/web/server.py"
EXAM_SRC="$HOME/.claude/ccaf-exam.local"
EXAM_DIR="$HOME/Documents/CCAF Exams"
WEB_ID_FILE="${EXAM_SRC}.web-id"
PID_FILE="$HOME/.claude/ccaf-web-server.pid"

[[ -f "$SERVER_PY" ]] || { echo "start-web-server: server.py not found at $SERVER_PY" >&2; exit 1; }
[[ -f "${EXAM_SRC}.md" ]] || { echo "start-web-server: no exam file at ${EXAM_SRC}.md" >&2; exit 1; }

# ── 1. Reuse existing export or create a new one ─────────────────────────────
mkdir -p "$EXAM_DIR"

# ── Backward compat: migrate exams from the legacy hidden location ────────────
# Earlier versions stored exams in ~/.claude/ccaf-exams. Move any that predate
# the relocation into ~/Documents/CCAF Exams so upgrading users keep their library.
LEGACY_EXAM_DIR="$HOME/.claude/ccaf-exams"
if [[ -d "$LEGACY_EXAM_DIR" ]]; then
  migrated=0
  for f in "$LEGACY_EXAM_DIR"/*.json; do
    [[ -e "$f" ]] || continue            # glob matched nothing
    dest="$EXAM_DIR/$(basename "$f")"
    [[ -e "$dest" ]] && continue         # never clobber a copy already in the new location
    mv "$f" "$dest" && migrated=$((migrated + 1))
  done
  rmdir "$LEGACY_EXAM_DIR" 2>/dev/null || true   # remove only if now empty
  if (( migrated > 0 )); then
    echo "Migrated ${migrated} exam file(s) from ${LEGACY_EXAM_DIR} to ${EXAM_DIR}."
  fi
fi

EXAM_ID=""
if [[ -f "$WEB_ID_FILE" ]]; then
  CANDIDATE=$(cat "$WEB_ID_FILE" 2>/dev/null || true)
  if [[ -n "$CANDIDATE" && -f "$EXAM_DIR/$CANDIDATE.json" ]]; then
    EXAM_ID="$CANDIDATE"
    echo "Reusing existing exam export ${EXAM_ID}."
  fi
fi

if [[ -z "$EXAM_ID" ]]; then
  EXAM_ID="ccaf-$(date +%Y%m%d-%H%M%S)"
  python3 "$SERVER_PY" export \
    --exam-id    "$EXAM_ID" \
    --exam-src   "$EXAM_SRC" \
    --exam-dir   "$EXAM_DIR" \
    --name       "${USER:-$(whoami)} - $(date +'%b %d, %Y')"
  echo "$EXAM_ID" > "$WEB_ID_FILE"
fi

# ── 3. Start server if not running ───────────────────────────────────────────
server_alive() {
  curl -s --max-time 1 "http://localhost:${PORT}/ping" 2>/dev/null | grep -q "pong"
}

if server_alive; then
  echo "Reusing existing server on port ${PORT}."
else
  # Clean up stale PID file
  if [[ -f "$PID_FILE" ]]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null || true)
    if [[ -n "$OLD_PID" ]] && kill -0 "$OLD_PID" 2>/dev/null; then
      kill "$OLD_PID" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
  fi

  SERVER_LOG="$HOME/.claude/ccaf-server.log"
  python3 "$SERVER_PY" serve \
    --port        "$PORT" \
    --exam-dir    "$EXAM_DIR" \
    --plugin-root "$PLUGIN_ROOT" \
    >> "$SERVER_LOG" 2>&1 &
  echo $! > "$PID_FILE"

  # Wait until server responds (up to 8 seconds)
  MAX=40
  for ((i=0; i<MAX; i++)); do
    sleep 0.2
    if server_alive; then break; fi
    if (( i == MAX - 1 )); then
      echo "start-web-server: server did not start in time" >&2
      [[ -s "$SERVER_LOG" ]] && echo "--- server log ---" >&2 && cat "$SERVER_LOG" >&2
      exit 1
    fi
  done
  echo "Server started (PID $(cat "$PID_FILE"))."
fi

# ── 4. Open browser ───────────────────────────────────────────────────────────
URL="http://localhost:${PORT}/?exam=${EXAM_ID}"
if command -v open &>/dev/null; then
  open "$URL"
elif command -v xdg-open &>/dev/null; then
  xdg-open "$URL"
else
  echo "Could not detect a browser opener (tried open, xdg-open)." >&2
fi

# ── 5. Output URL for the skill to relay ─────────────────────────────────────
echo "Exam open at: ${URL}"
