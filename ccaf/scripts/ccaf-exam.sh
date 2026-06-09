#!/usr/bin/env bash
set -eo pipefail

# ccaf-exam.sh — Silent state persistence for the /ccaf:mock-exam mock exam.
#
# Called via Bash from the ccaf-exam skill to avoid Write/Edit permission prompts.
# Operates on a single per-attempt file (default ~/.claude/ccaf-exam.local.md;
# override with CCAF_EXAM_FILE, used by tests).
#
# Usage:
#   ccaf-exam.sh init                 # read full exam body from stdin, write the file
#   ccaf-exam.sh get                  # print the whole file
#   ccaf-exam.sh get --field status   # print one frontmatter field (status|next_index|total)
#   ccaf-exam.sh record --q 7 --answer C   # record an answer, advance next_index
#   ccaf-exam.sh score                # tally + scaled score + per-domain; mark completed
#   ccaf-exam.sh clear                # remove the file
#
# Exam file format (frontmatter + one block per question):
#   ---
#   status: in_progress            # in_progress | completed
#   total: 60
#   scenarios: a,b,c,d
#   next_index: 1
#   ---
#   [[Q1]]
#   domain: D1
#   scenario: customer-support
#   source: authored
#   id: seed-01
#   stem: ...
#   A) ...
#   B) ...
#   C) ...
#   D) ...
#   answer_key: A
#   user_answer:
#   [[Q2]]
#   ...
#
# The script only reads/writes the frontmatter fields and each block's
# `domain:`, `answer_key:`, and `user_answer:` lines. Everything else is opaque.

EXAM_FILE="${CCAF_EXAM_FILE:-$HOME/.claude/ccaf-exam.local.md}"

die() { echo "ccaf-exam: $*" >&2; exit 1; }

require_file() {
  [[ -f "$EXAM_FILE" ]] || die "no active exam at $EXAM_FILE"
}

read_field() {
  # Reads a frontmatter field from the first --- block.
  local key="$1"
  awk -v k="$key" '
    /^---$/ { fm++; next }
    fm == 1 && $0 ~ "^" k ":" {
      sub("^" k ":[[:space:]]*", "")
      print
      exit
    }
  ' "$EXAM_FILE"
}

set_field() {
  # Replaces a frontmatter field value in place (first --- block).
  local key="$1" value="$2" tmp
  tmp="$(mktemp)"
  awk -v k="$key" -v v="$value" '
    /^---$/ { fm++ }
    fm == 1 && $0 ~ "^" k ":" { print k ": " v; next }
    { print }
  ' "$EXAM_FILE" > "$tmp"
  mv "$tmp" "$EXAM_FILE"
}

recompute_next_index() {
  # next_index = lowest question number with an empty user_answer, else total+1.
  local total next
  total="$(read_field total)"
  next="$(awk '
    /^\[\[Q[0-9]+\]\]$/ {
      qn = $0; gsub(/[^0-9]/, "", qn); cur = qn + 0; ua = ""
    }
    /^user_answer:/ {
      val = $0; sub(/^user_answer:[[:space:]]*/, "", val)
      if (val == "" && cur > 0 && (found == 0 || cur < found)) found = cur
    }
    END { print (found ? found : 0) }
  ' "$EXAM_FILE")"
  if [[ "$next" -eq 0 ]]; then
    next=$(( total + 1 ))
  fi
  set_field next_index "$next"
}

cmd_init() {
  mkdir -p "$(dirname "$EXAM_FILE")"
  cat > "$EXAM_FILE"   # body from stdin
  echo "Exam written to $EXAM_FILE"
}

cmd_get() {
  require_file
  if [[ "${1:-}" == "--field" ]]; then
    [[ -n "${2:-}" ]] || die "get --field needs a field name"
    read_field "$2"
  else
    cat "$EXAM_FILE"
  fi
}

cmd_record() {
  require_file
  local q="" answer=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --q)      q="$2";      shift 2 ;;
      --answer) answer="$2"; shift 2 ;;
      *) die "record: unknown flag $1" ;;
    esac
  done
  [[ "$q" =~ ^[0-9]+$ ]] || die "record: --q must be a question number"
  [[ "$answer" =~ ^[A-D]$ ]] || die "record: --answer must be one of A B C D"

  local tmp
  tmp="$(mktemp)"
  awk -v target="$q" -v ans="$answer" '
    /^\[\[Q[0-9]+\]\]$/ {
      qn = $0; gsub(/[^0-9]/, "", qn); cur = qn + 0
    }
    /^user_answer:/ && cur == target { print "user_answer: " ans; done=1; next }
    { print }
    END { if (!done) exit 3 }
  ' "$EXAM_FILE" > "$tmp" || die "record: question $q not found"
  mv "$tmp" "$EXAM_FILE"
  recompute_next_index
  echo "Recorded Q$q=$answer; next_index=$(read_field next_index)"
}

cmd_score() {
  require_file
  awk '
    BEGIN { total = 0; correct = 0 }
    /^\[\[Q[0-9]+\]\]$/ { domain=""; key=""; ua=""; inblock=1; next }
    inblock && /^domain:/      { domain=$0; sub(/^domain:[[:space:]]*/, "", domain) }
    inblock && /^answer_key:/  { key=$0;    sub(/^answer_key:[[:space:]]*/, "", key) }
    inblock && /^user_answer:/ {
      ua=$0; sub(/^user_answer:[[:space:]]*/, "", ua)
      # end of a question block (user_answer is the last field per block)
      total++
      dtotal[domain]++
      if (ua != "" && ua == key) { correct++; dcorrect[domain]++ }
      inblock=0
    }
    END {
      # scaled = 100 + round(correct/total * 900). For the production 60-question
      # exam this is exactly 100 + 15*correct (since 900/60 = 15).
      scaled = (total > 0) ? 100 + int(correct * 900 / total + 0.5) : 100
      verdict = (scaled >= 720) ? "PASS" : "FAIL"
      printf "correct=%d/%d\n", correct, total
      printf "scaled=%d\n", scaled
      printf "verdict=%s\n", verdict
      n = split("D1,D2,D3,D4,D5", doms, ",")
      for (i = 1; i <= n; i++) {
        d = doms[i]
        printf "domain=%s correct=%d total=%d\n", d, dcorrect[d]+0, dtotal[d]+0
      }
    }
  ' "$EXAM_FILE"
  set_field status completed
}

cmd_clear() {
  rm -f "$EXAM_FILE"
  echo "Exam cleared."
}

[[ $# -ge 1 ]] || die "usage: ccaf-exam.sh {init|get|record|score|clear} [...]"
command="$1"; shift
case "$command" in
  init)   cmd_init "$@" ;;
  get)    cmd_get "$@" ;;
  record) cmd_record "$@" ;;
  score)  cmd_score "$@" ;;
  clear)  cmd_clear "$@" ;;
  *) die "unknown command: $command" ;;
esac
