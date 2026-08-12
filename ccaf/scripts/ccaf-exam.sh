#!/usr/bin/env bash
set -eo pipefail

# ccaf-exam.sh — Silent state persistence for the /ccaf:mock-exam mock exam.
#
# Called via Bash from the ccaf-exam skill to avoid Write/Edit permission prompts.
# An attempt is a PAIR of files (override the base path with CCAF_EXAM_FILE; the
# answers path derives from it):
#
#   Questions file (default ~/.claude/ccaf-exam.local.md) — write-once at init:
#   frontmatter (total, scenarios) + [[CASE:]] blocks + [[Q]] blocks with stems,
#   options, and each item's `task:` statement, but NO answer keys and NO user
#   answers. Safe to read and show during administration; recording never
#   rewrites it.
#
#   Answers file (<questions-file minus .md>.answers.md) — small and hot:
#   status + next_index frontmatter, then one "qnum domain key user" line per
#   question ("-" = unanswered). Recording rewrites only this file, and the
#   skill never reads it during administration, so answer keys stay out of the
#   conversation.
#
# Every item is single-answer multiple-choice: four options A-D, exactly one
# correct. Recorded answers are uppercased so a lowercase free-text reply matches.
#
# Usage:
#   ccaf-exam.sh init [--force]       # read the full exam payload from stdin (one
#                                     # body WITH answer_key/user_answer lines),
#                                     # validate, then split-write the two files
#                                     # (refuses to overwrite an in-progress attempt
#                                     #  unless --force; 60-question exams must match
#                                     #  the CCAF blueprint composition)
#   ccaf-exam.sh get                  # print the questions file (key-free)
#   ccaf-exam.sh get --field status   # one frontmatter field (status|next_index from
#                                     # the answers file; total|scenarios from the
#                                     # questions file)
#   ccaf-exam.sh record --q 7 --answer C [--q 8 --answer A ...]
#                                     # record one or more answers in a single call
#                                     # (atomic), then advance next_index; an answer
#                                     # is one letter A-D, case-insensitive
#   ccaf-exam.sh blanks               # unanswered question numbers, one per line
#   ccaf-exam.sh audit                # composition (total, scenarios, per-domain and
#                                     # per-key counts) + composition=OK|FAIL
#   ccaf-exam.sh score [--partial]    # tally + scaled score + per-domain correct and
#                                     # percent + per-task-statement correct/total;
#                                     # mark completed (refuses unanswered questions
#                                     # unless --partial)
#   ccaf-exam.sh clear                # remove both files
#
# init payload format (frontmatter + one [[CASE:]] block per scenario section +
# one block per question; questions grouped contiguously by scenario):
#   ---
#   status: in_progress            # in_progress | completed
#   total: 60
#   scenarios: a,b,c,d
#   next_index: 1
#   ---
#   [[CASE:customer-support]]
#   title: Customer Support Resolution Agent
#   brief: ...                     # shown above every screen of this section
#   [[Q1]]
#   domain: D1
#   task: D1.4                   # the task statement tested; must exist in `domain`
#   scenario: customer-support
#   source: generated            # always generated — bank questions are reference-only
#   id: gen-01
#   stem: ...
#   A) ...
#   B) ...
#   C) ...
#   D) ...
#   answer_key: A                # exactly one letter A-D
#   user_answer:
#   [[Q2]]
#   ...

EXAM_FILE="${CCAF_EXAM_FILE:-$HOME/.claude/ccaf-exam.local.md}"
ANSWERS_FILE="${EXAM_FILE%.md}.answers.md"
LOCK_DIR="$EXAM_FILE.lock"

# Composition the blueprint fixes for a full mock (see data/ccaf-blueprint.md).
# Only exams of BLUEPRINT_TOTAL items are held to it; shorter practice sessions
# set their own proportional quotas and are validated structurally only.
BLUEPRINT_TOTAL=60
BLUEPRINT_DOMAIN_QUOTAS="D1=16 D2=11 D3=12 D4=12 D5=9"
BLUEPRINT_SCENARIOS=4
# How many task statements each domain publishes (D1.1-D1.7, D2.1-D2.5, ...).
# Used to reject an item tagged with a task statement that does not exist.
BLUEPRINT_TASK_COUNTS="D1=7 D2=5 D3=6 D4=6 D5=6"

die() { echo "ccaf-exam: $*" >&2; exit 1; }

normalize_answer() {
  # "b" -> "B", so a candidate typing a lowercase letter into the free-text field
  # records the same as one picking the option. Rejects anything else.
  # Deliberately pure bash: record runs once per exam screen, and spawning a
  # pipeline per answer is a visible cost where process creation is slow.
  case "$1" in
    a | A) printf A ;;
    b | B) printf B ;;
    c | C) printf C ;;
    d | D) printf D ;;
    *) return 1 ;;
  esac
}

# Mutating commands may be launched in the background while the next screen is
# already showing, so writes are serialized through a directory lock. No
# legitimate holder runs longer than a second; a lock that old is stale (a
# killed process) and is stolen at the halfway mark.
release_lock() { rmdir "$LOCK_DIR" 2>/dev/null || true; }
acquire_lock() {
  mkdir -p "$(dirname "$LOCK_DIR")"
  local max="${CCAF_LOCK_WAIT_ITERS:-200}" i   # 200 x 0.1s = 20s ceiling
  for ((i = 0; i < max; i++)); do
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      trap release_lock EXIT
      return 0
    fi
    if (( i == max / 2 )); then rm -rf "$LOCK_DIR"; fi
    sleep 0.1
  done
  die "could not acquire state lock at $LOCK_DIR (remove it if stale)"
}

# Temp files live next to the exam files so the final rename is atomic — readers
# never observe a half-written file.
state_tmp() { mktemp "$(dirname "$EXAM_FILE")/.ccaf-exam.tmp.XXXXXX"; }

require_attempt() {
  [[ -f "$EXAM_FILE" && -f "$ANSWERS_FILE" ]] || die "no active exam at $EXAM_FILE"
}

read_field_from() {
  # Reads a frontmatter field from an arbitrary file (first --- block).
  local key="$1" file="$2"
  awk -v k="$key" '
    /^---$/ { fm++; next }
    fm == 1 && $0 ~ "^" k ":" {
      sub("^" k ":[[:space:]]*", "")
      print
      exit
    }
  ' "$file"
}

read_field() {
  # Mutable fields live in the answers file; static ones in the questions file.
  local key="$1" f="$EXAM_FILE"
  case "$key" in status|next_index) f="$ANSWERS_FILE" ;; esac
  read_field_from "$key" "$f"
}

set_field() {
  # Replaces a frontmatter field value in place. Only mutable fields are ever
  # set, and those live in the answers file.
  local key="$1" value="$2" tmp
  tmp="$(state_tmp)"
  awk -v k="$key" -v v="$value" '
    /^---$/ { fm++ }
    fm == 1 && $0 ~ "^" k ":" { print k ": " v; next }
    { print }
  ' "$ANSWERS_FILE" > "$tmp"
  mv "$tmp" "$ANSWERS_FILE"
}

recompute_next_index() {
  # next_index = lowest question number with no recorded answer, else total+1.
  local total next
  total="$(read_field_from total "$ANSWERS_FILE")"
  next="$(awk '/^[0-9]+ / && $4 == "-" { print $1; exit }' "$ANSWERS_FILE")"
  [[ -n "$next" ]] || next=$(( total + 1 ))
  set_field next_index "$next"
}

count_blanks() {
  awk '/^[0-9]+ / && $4 == "-" { n++ } END { print n + 0 }' "$ANSWERS_FILE"
}

check_items() {
  # Per-item integrity on an init payload: exactly one correct option A-D, and a
  # `task:` statement that exists and belongs to the item's own domain. The task
  # tag is validated rather than trusted because the score report aggregates
  # misses by task statement, and a mistagged item would send a candidate to
  # study the wrong objective. Prints the first offending question, empty output
  # when every item is well-formed.
  local file="$1"
  awk -v taskcounts="$BLUEPRINT_TASK_COUNTS" '
    BEGIN {
      n = split(taskcounts, pairs, " ")
      for (i = 1; i <= n; i++) { split(pairs[i], kv, "="); taskmax[kv[1]] = kv[2] + 0 }
    }
    /^\[\[Q[0-9]+\]\]$/ { q = $0; gsub(/[^0-9]/, "", q); dom = ""; task = ""; next }
    /^domain: /     { dom = $2; next }
    /^task: /       { task = $2; next }
    /^answer_key: / {
      key = $2
      if (key !~ /^[A-D]$/)           { print "Q" q " answer_key " key " must be one letter A-D"; exit }
      if (task == "")                 { print "Q" q " has no task: line"; exit }
      if (task !~ /^D[1-5]\.[0-9]+$/) { print "Q" q " task: " task " must look like D1.4"; exit }
      td = substr(task, 1, 2)
      if (td != dom)                  { print "Q" q " task: " task " does not belong to its domain " dom; exit }
      tn = substr(task, 4) + 0
      if (tn < 1 || tn > taskmax[td]) { print "Q" q " task: " task " — " td " has task statements " td ".1 to " td "." taskmax[td]; exit }
      next
    }
    /^user_answer:/ {
      ua = $0; sub(/^user_answer:[[:space:]]*/, "", ua)
      if (ua != "" && ua !~ /^[A-D]$/) { print "Q" q " user_answer " ua " must be one letter A-D or empty"; exit }
    }
  ' "$file"
}

check_composition_questions() {
  # Full-mock blueprint checks on the questions side: domain quotas, the scenario
  # count, and contiguous case-headed sections (each [[CASE:slug]] appears once
  # and directly heads a run of its own questions — so the brief shown above a
  # screen always belongs to that screen's questions, never a previous case).
  # Also valid against an init payload; the extra answer lines are ignored.
  #
  # One awk pass, not a dozen greps: this runs on every init and every score,
  # and process creation is expensive enough on some machines (Windows + AV)
  # that a per-check subprocess is the dominant cost. Structural problems are
  # recorded rather than reported immediately, so failures still surface in the
  # documented order — quotas, scenarios, then layout.
  # Prints the reason on failure.
  local file="$1" reason
  reason="$(awk -v quotas="$BLUEPRINT_DOMAIN_QUOTAS" -v wantscen="$BLUEPRINT_SCENARIOS" '
    BEGIN {
      ndom = split(quotas, pairs, " ")
      for (i = 1; i <= ndom; i++) { split(pairs[i], kv, "="); domname[i] = kv[1]; domwant[i] = kv[2] + 0 }
    }
    /^---$/ { fm++; next }
    fm == 1 && /^scenarios:/ {
      line = $0; sub(/^scenarios:[[:space:]]*/, "", line)
      n = split(line, raw, ",")
      for (i = 1; i <= n; i++) {
        s = raw[i]; gsub(/^[ \t]+|[ \t]+$/, "", s)
        if (s != "" && !(s in listed)) { listed[s] = 1; order[++scencount] = s }
      }
      next
    }
    /^\[\[CASE:[a-z-]+\]\]$/ {
      c = $0; sub(/^\[\[CASE:/, "", c); sub(/\]\]$/, "", c)
      if (caseseen[c]++ && struct == "") struct = "case block " c " appears more than once (sections must be contiguous)"
      cur = c
      next
    }
    /^domain: /  { domgot[$2]++; next }
    /^scenario: / {
      s = $2; qscen[s]++
      if (struct == "") {
        if (cur == "")     struct = "a question with scenario " s " appears before any [[CASE:]] block"
        else if (s != cur) struct = "a question with scenario " s " sits under case block " cur " — each section must be contiguous, headed by its own case block"
      }
      next
    }
    END {
      for (i = 1; i <= ndom; i++) {
        d = domname[i]
        if (domgot[d] + 0 != domwant[i]) {
          printf "domain %s has %d questions, blueprint requires %d\n", d, domgot[d] + 0, domwant[i]; exit }
      }
      if (scencount + 0 != wantscen) { printf "frontmatter lists %d scenarios, need exactly %d\n", scencount + 0, wantscen; exit }
      for (i = 1; i <= scencount; i++) {
        s = order[i]
        if (!(s in qscen))    { printf "scenario %s is listed but has no questions\n", s; exit }
        if (!(s in caseseen)) { printf "scenario %s is missing its [[CASE:%s]] case-study block\n", s, s; exit }
      }
      for (s in qscen) if (!(s in listed)) { printf "question scenario %s is not in the frontmatter scenario list\n", s; exit }
      if (struct != "") print struct
    }
  ' "$file")"
  [[ -z "$reason" ]] || { echo "$reason"; return 1; }
  return 0
}

check_key_spread() {
  # Reject answer-position bias. Only full mocks reach here, so the band is
  # deliberately tight — a sixth to a third of items per letter, against an even
  # share of a quarter. The reference bank's own key positions are lopsided, so
  # few-shot pull toward one letter is a real risk; enforcing the property here
  # is worth more than trusting the examples to teach it.
  # mode "payload": read `answer_key:` lines; mode "answers": read column 3.
  local file="$1" mode="$2" reason
  reason="$(awk -v mode="$mode" '
    mode == "payload" && /^answer_key: [A-D]$/ { key[$2]++; items++ }
    mode == "answers" && /^[0-9]+ /            { key[$3]++; items++ }
    END {
      if (items < 8) exit
      lo = int(items / 6); hi = int(items / 3)
      n = split("A,B,C,D", letters, ",")
      for (i = 1; i <= n; i++) {
        L = letters[i]; c = key[L] + 0
        if (c < lo || c > hi) {
          printf "answer key %s appears %d/%d times — positions look biased (aim ~%d each); reshuffle\n", L, c, items, int(items / 4)
          exit
        }
      }
    }
  ' "$file")"
  [[ -z "$reason" ]] || { echo "$reason"; return 1; }
  return 0
}

validate_payload() {
  # Structural integrity of an init payload: total is numeric and the [[Qn]] /
  # task / answer_key / user_answer line counts all equal it. For a full 60-item
  # exam, also enforces the CCAF blueprint composition.
  # Prints the reason on failure.
  local file="$1" total blocks tasks keys uas reason
  total="$(read_field_from total "$file")"
  if ! [[ "$total" =~ ^[0-9]+$ && "$total" -gt 0 ]]; then
    echo "frontmatter 'total' missing or non-numeric"; return 1
  fi
  blocks="$(grep -cE '^\[\[Q[0-9]+\]\]$' "$file" || true)"
  tasks="$(grep -cE '^task:[[:space:]]*D[1-5]\.[0-9]+[[:space:]]*$' "$file" || true)"
  keys="$(grep -cE '^answer_key:[[:space:]]*[A-D][[:space:]]*$' "$file" || true)"
  uas="$(grep -c '^user_answer:' "$file" || true)"
  if [[ "$blocks" -ne "$total" || "$tasks" -ne "$total" || "$keys" -ne "$total" || "$uas" -ne "$total" ]]; then
    echo "body mismatch: total=$total but blocks=$blocks tasks=$tasks keys=$keys user_answers=$uas"; return 1
  fi
  reason="$(check_items "$file")"
  [[ -z "$reason" ]] || { echo "$reason"; return 1; }
  # The question bank is reference-only (it ships in the repo, answers included,
  # so anyone may have read it) — bank questions must never be served.
  if grep -qE '^(source: authored|id: seed-|id: ref-)' "$file"; then
    echo "bank questions are reference-only: found 'source: authored' / 'id: seed-*' in the exam"; return 1
  fi
  if [[ "$total" -eq "$BLUEPRINT_TOTAL" ]]; then
    if ! reason="$(check_composition_questions "$file")"; then echo "$reason"; return 1; fi
    if ! reason="$(check_key_spread "$file" payload)"; then echo "$reason"; return 1; fi
  fi
  return 0
}

validate_pair() {
  # Cross-file integrity of an on-disk attempt. Prints the reason on failure.
  local qt at blocks lines tasks reason
  qt="$(read_field_from total "$EXAM_FILE")"
  at="$(read_field_from total "$ANSWERS_FILE")"
  if ! [[ "$qt" =~ ^[0-9]+$ && "$qt" -gt 0 ]]; then
    echo "questions file 'total' missing or non-numeric"; return 1
  fi
  [[ "$qt" == "$at" ]] || { echo "totals diverge: questions file says $qt, answers file says $at"; return 1; }
  blocks="$(grep -cE '^\[\[Q[0-9]+\]\]$' "$EXAM_FILE" || true)"
  [[ "$blocks" -eq "$qt" ]] || { echo "questions file has $blocks blocks but total=$qt"; return 1; }
  lines="$(grep -cE '^[0-9]+ D[1-5] [A-D] ([A-D]|-)$' "$ANSWERS_FILE" || true)"
  [[ "$lines" -eq "$qt" ]] || { echo "answers file has $lines well-formed lines but total=$qt"; return 1; }
  tasks="$(grep -cE '^task:[[:space:]]*D[1-5]\.[0-9]+[[:space:]]*$' "$EXAM_FILE" || true)"
  [[ "$tasks" -eq "$qt" ]] || { echo "questions file has $tasks task: lines but total=$qt"; return 1; }
  if grep -qE '^(source: authored|id: seed-|id: ref-)' "$EXAM_FILE"; then
    echo "bank questions are reference-only: found 'source: authored' / 'id: seed-*' in the exam"; return 1
  fi
  if [[ "$qt" -eq "$BLUEPRINT_TOTAL" ]]; then
    if ! reason="$(check_composition_questions "$EXAM_FILE")"; then echo "$reason"; return 1; fi
    if ! reason="$(check_key_spread "$ANSWERS_FILE" answers)"; then echo "$reason"; return 1; fi
  fi
  return 0
}

cmd_init() {
  local force=0
  [[ "${1:-}" == "--force" ]] && force=1
  acquire_lock
  if [[ -f "$EXAM_FILE" && -f "$ANSWERS_FILE" && "$force" -eq 0 ]]; then
    local existing_status
    existing_status="$(read_field_from status "$ANSWERS_FILE")"
    [[ "$existing_status" == "in_progress" ]] && \
      die "init: an in-progress attempt exists at $EXAM_FILE — run 'clear' first or use 'init --force'"
  fi
  mkdir -p "$(dirname "$EXAM_FILE")"
  local payload reason qtmp atmp
  payload="$(state_tmp)"
  tr -d '\r' > "$payload"   # payload from stdin; normalize CRLF so awk parsing is OS-independent
  if ! reason="$(validate_payload "$payload")"; then
    rm -f "$payload"
    die "init: malformed exam body ($reason) — nothing written"
  fi
  qtmp="$(state_tmp)"; atmp="$(state_tmp)"
  # Questions file: the payload minus keys, recorded answers, and mutable fields.
  grep -vE '^(answer_key:|user_answer:|status:|next_index:)' "$payload" > "$qtmp" || true
  # Answers file: mutable frontmatter + one "qnum domain key user" line per question.
  awk '
    /^---$/ { fm++; next }
    fm == 1 && /^status:/     { s = $0; sub(/^status:[[:space:]]*/, "", s); next }
    fm == 1 && /^total:/      { t = $0; sub(/^total:[[:space:]]*/, "", t); next }
    fm == 1 && /^next_index:/ { n = $0; sub(/^next_index:[[:space:]]*/, "", n); next }
    /^\[\[Q[0-9]+\]\]$/ { q = $0; gsub(/[^0-9]/, "", q) }
    /^domain: /     { d = $2 }
    /^answer_key: / { k = $2 }
    /^user_answer:/ {
      u = $0; sub(/^user_answer:[[:space:]]*/, "", u)
      if (u == "") u = "-"
      body = body q " " d " " k " " u "\n"
    }
    END { printf "---\nstatus: %s\ntotal: %s\nnext_index: %s\n---\n%s", s, t, n, body }
  ' "$payload" > "$atmp"
  rm -f "$payload"
  mv "$qtmp" "$EXAM_FILE"
  mv "$atmp" "$ANSWERS_FILE"
  echo "Exam written to $EXAM_FILE (answers in $ANSWERS_FILE)"
}

cmd_get() {
  require_attempt
  if [[ "${1:-}" == "--field" ]]; then
    [[ -n "${2:-}" ]] || die "get --field needs a field name"
    read_field "$2"
  else
    cat "$EXAM_FILE"   # key-free by construction
  fi
}

cmd_record() {
  require_attempt
  # Accepts one or more --q/--answer pairs and applies them in a single atomic
  # rewrite of the small answers file — the questions file is never touched.
  local -a qs=() answers=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --q)      qs+=("$2");      shift 2 ;;
      --answer) answers+=("$2"); shift 2 ;;
      *) die "record: unknown flag $1" ;;
    esac
  done
  [[ ${#qs[@]} -ge 1 && ${#qs[@]} -eq ${#answers[@]} ]] || die "record: provide matching --q/--answer pairs"
  local i normalized pairs=""
  for ((i = 0; i < ${#qs[@]}; i++)); do
    [[ "${qs[$i]}" =~ ^[0-9]+$ ]] || die "record: --q must be a question number (got '${qs[$i]}')"
    normalized="$(normalize_answer "${answers[$i]}")" ||
      die "record: --answer must be one letter from A-D (got '${answers[$i]}')"
    pairs+="${qs[$i]}=${normalized},"
  done
  acquire_lock
  local status
  status="$(read_field status)"
  [[ "$status" == "in_progress" ]] || die "record: attempt is not in progress (status: ${status:-unreadable})"

  local tmp
  tmp="$(state_tmp)"
  awk -v pairs="$pairs" -v expected="${#qs[@]}" '
    BEGIN {
      n = split(pairs, kv, ",")
      for (i = 1; i <= n; i++) if (kv[i] != "") { split(kv[i], p, "="); ans[p[1] + 0] = p[2] }
    }
    /^[0-9]+ / && (($1 + 0) in ans) && !seen[$1 + 0]++ { $4 = ans[$1 + 0]; done++ }
    { print }
    END { if (done != expected) exit 3 }
  ' "$ANSWERS_FILE" > "$tmp" || { rm -f "$tmp"; die "record: could not record all answers (a question number is missing or duplicated) — nothing was recorded"; }
  mv "$tmp" "$ANSWERS_FILE"
  recompute_next_index
  echo "Recorded ${#qs[@]} answer(s); next_index=$(read_field next_index)"
}

cmd_blanks() {
  require_attempt
  awk '/^[0-9]+ / && $4 == "-" { print $1 }' "$ANSWERS_FILE"
}

cmd_audit() {
  require_attempt
  local d letter sel reason
  echo "total=$(read_field total)"
  echo "scenarios=$(read_field scenarios)"
  for d in D1 D2 D3 D4 D5; do
    echo "domain=$d questions=$(grep -c "^domain: $d\$" "$EXAM_FILE" || true)"
  done
  for letter in A B C D; do
    echo "key=$letter count=$(awk -v L="$letter" '/^[0-9]+ / && $3 == L { n++ } END { print n + 0 }' "$ANSWERS_FILE")"
  done
  if reason="$(validate_pair)"; then
    echo "composition=OK"
  else
    echo "composition=FAIL ($reason)"
    return 1
  fi
}

cmd_score() {
  require_attempt
  acquire_lock
  local partial=0 reason blanks
  [[ "${1:-}" == "--partial" ]] && partial=1
  if ! reason="$(validate_pair)"; then
    die "score: attempt failed integrity check ($reason) — refusing to score"
  fi
  blanks="$(count_blanks)"
  if [[ "$partial" -eq 0 && "$blanks" -gt 0 ]]; then
    die "score: $blanks question(s) unanswered — use 'score --partial' to submit incomplete (blanks count as incorrect)"
  fi
  # Reads both files: the questions file supplies each item's task statement (it
  # is not in the answers file), so misses can be attributed to the specific
  # objective a candidate should go study rather than only to its domain.
  awk '
    FNR == NR {
      if ($0 ~ /^\[\[Q[0-9]+\]\]$/) { q = $0; gsub(/[^0-9]/, "", q) }
      else if ($0 ~ /^task: /)      { qtask[q + 0] = $2 }
      next
    }
    /^[0-9]+ / {
      total++; dtotal[$2]++
      t = qtask[$1 + 0]
      if (t != "") {
        if (!(t in seentask)) { seentask[t] = 1; taskorder[++ntask] = t }
        ttotal[t]++
      }
      if ($4 != "-" && $4 == $3) {
        correct++; dcorrect[$2]++
        if (t != "") tcorrect[t]++
      }
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
        pct = (dtotal[d] > 0) ? int(dcorrect[d] * 100 / dtotal[d] + 0.5) : 0
        printf "domain=%s correct=%d total=%d pct=%d\n", d, dcorrect[d] + 0, dtotal[d] + 0, pct
      }
      # Question order, so the report is stable across runs of the same attempt.
      for (i = 1; i <= ntask; i++) {
        t = taskorder[i]
        printf "task=%s correct=%d total=%d\n", t, tcorrect[t] + 0, ttotal[t]
      }
    }
  ' "$EXAM_FILE" "$ANSWERS_FILE"
  set_field status completed
}

cmd_clear() {
  acquire_lock
  rm -f "$EXAM_FILE" "$ANSWERS_FILE"
  echo "Exam cleared."
}

[[ $# -ge 1 ]] || die "usage: ccaf-exam.sh {init|get|record|blanks|audit|score|clear} [...]"
command="$1"; shift
case "$command" in
  init)   cmd_init "$@" ;;
  get)    cmd_get "$@" ;;
  record) cmd_record "$@" ;;
  blanks) cmd_blanks "$@" ;;
  audit)  cmd_audit "$@" ;;
  score)  cmd_score "$@" ;;
  clear)  cmd_clear "$@" ;;
  *) die "unknown command: $command" ;;
esac
