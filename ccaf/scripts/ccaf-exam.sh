#!/usr/bin/env bash
set -eo pipefail

# ccaf-exam.sh — Silent state persistence for the /ccaf:mock-exam mock exam.
#
# Called via Bash from the ccaf-exam skill to avoid Write/Edit permission prompts.
# An attempt is a PAIR of files (override the base path with CCAF_EXAM_FILE; the
# answers path derives from it):
#
#   Questions file (default ~/.claude/ccaf-exam.local.md) — write-once at init:
#   frontmatter (total, scenarios) + [[CASE:]] blocks + [[Q]] blocks with stems
#   and options but NO answer keys and NO user answers. Safe to read and show
#   during administration; recording never rewrites it.
#
#   Answers file (<questions-file minus .md>.answers.md) — small and hot:
#   status + next_index frontmatter, then one "qnum domain key user" line per
#   question ("-" = unanswered). Recording rewrites only this file, and the
#   skill never reads it during administration, so answer keys stay out of the
#   conversation.
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
#                                     # (atomic), then advance next_index
#   ccaf-exam.sh blanks               # unanswered question numbers, one per line
#   ccaf-exam.sh audit                # composition (total, scenarios, per-domain and
#                                     # per-key counts) + composition=OK|FAIL
#   ccaf-exam.sh score [--partial]    # tally + scaled score + per-domain; mark
#                                     # completed (refuses unanswered questions
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
#   scenario: customer-support
#   source: generated            # always generated — bank questions are reference-only
#   id: gen-01
#   stem: ...
#   A) ...
#   B) ...
#   C) ...
#   D) ...
#   answer_key: A
#   user_answer:
#   [[Q2]]
#   ...

EXAM_FILE="${CCAF_EXAM_FILE:-$HOME/.claude/ccaf-exam.local.md}"
ANSWERS_FILE="${EXAM_FILE%.md}.answers.md"
WEB_ID_FILE="${EXAM_FILE%.md}.web-id"
LOCK_DIR="$EXAM_FILE.lock"

die() { echo "ccaf-exam: $*" >&2; exit 1; }

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

check_composition_questions() {
  # 60-question blueprint checks on the questions side: domain quotas, exactly
  # 4 scenarios, contiguous case-headed sections. Also valid against an init
  # payload (the extra answer lines are ignored). Prints the reason on failure.
  local file="$1"
  local pair d want got
  for pair in D1=16 D2=11 D3=12 D4=12 D5=9; do
    d="${pair%%=*}"; want="${pair##*=}"
    got="$(grep -c "^domain: $d\$" "$file" || true)"
    [[ "$got" -eq "$want" ]] || { echo "domain $d has $got questions, blueprint requires $want"; return 1; }
  done
  local scen_line scen_count s
  scen_line="$(read_field_from scenarios "$file")"
  scen_count="$(tr ',' '\n' <<<"$scen_line" | sed '/^$/d' | sort -u | wc -l | tr -d '[:space:]')"
  [[ "$scen_count" -eq 4 ]] || { echo "frontmatter lists $scen_count scenarios, need exactly 4"; return 1; }
  for s in ${scen_line//,/ }; do
    got="$(grep -c "^scenario: $s\$" "$file" || true)"
    [[ "$got" -ge 1 ]] || { echo "scenario $s is listed but has no questions"; return 1; }
    grep -q "^\[\[CASE:$s\]\]\$" "$file" || { echo "scenario $s is missing its [[CASE:$s]] case-study block"; return 1; }
  done
  local bs
  while IFS= read -r bs; do
    [[ ",$scen_line," == *",$bs,"* ]] || { echo "question scenario '$bs' is not in the frontmatter scenario list"; return 1; }
  done < <(grep '^scenario: ' "$file" | sed 's/^scenario: //' | sort -u)
  # Case-study structure: each [[CASE:slug]] appears exactly once and directly
  # heads a contiguous run of its own questions — so the brief shown above a
  # screen always belongs to that screen's questions, never a previous case.
  # Slug grammar [a-z0-9-]+ — keep in sync with web/server.py parse_questions_file.
  local struct
  struct="$(awk '
    /^\[\[CASE:[a-z0-9-]+\]\]$/ {
      c = $0; sub(/^\[\[CASE:/, "", c); sub(/\]\]$/, "", c)
      if (seen[c]++) { print "case block " c " appears more than once (sections must be contiguous)"; exit }
      cur = c; next
    }
    /^scenario: / {
      s = $0; sub(/^scenario: /, "", s)
      if (cur == "") { print "a question with scenario " s " appears before any [[CASE:]] block"; exit }
      if (s != cur)  { print "a question with scenario " s " sits under case block " cur " — each section must be contiguous, headed by its own case block"; exit }
    }
  ' "$file")"
  [[ -z "$struct" ]] || { echo "$struct"; return 1; }
  return 0
}

check_key_spread() {
  # Catch degenerate answer-position bias (uniform random ≈ 15 each on 60).
  # mode "payload": count `answer_key:` lines; mode "answers": count column 3.
  local file="$1" mode="$2" letter cnt
  for letter in A B C D; do
    if [[ "$mode" == "payload" ]]; then
      cnt="$(grep -c "^answer_key: $letter\$" "$file" || true)"
    else
      cnt="$(awk -v L="$letter" '/^[0-9]+ / && $3 == L { n++ } END { print n + 0 }' "$file")"
    fi
    if [[ "$cnt" -lt 6 || "$cnt" -gt 26 ]]; then
      echo "answer key '$letter' appears $cnt/60 times — positions look biased (aim ~15 each); reshuffle"; return 1
    fi
  done
  return 0
}

validate_payload() {
  # Structural integrity of an init payload: total is numeric and the [[Qn]] /
  # answer_key / user_answer line counts all equal it. For the production
  # 60-question exam, also enforces the CCAF blueprint composition.
  # Prints the reason on failure.
  local file="$1" total blocks keys uas reason
  total="$(read_field_from total "$file")"
  if ! [[ "$total" =~ ^[0-9]+$ && "$total" -gt 0 ]]; then
    echo "frontmatter 'total' missing or non-numeric"; return 1
  fi
  blocks="$(grep -cE '^\[\[Q[0-9]+\]\]$' "$file" || true)"
  keys="$(grep -cE '^answer_key:[[:space:]]*[A-D][[:space:]]*$' "$file" || true)"
  uas="$(grep -c '^user_answer:' "$file" || true)"
  if [[ "$blocks" -ne "$total" || "$keys" -ne "$total" || "$uas" -ne "$total" ]]; then
    echo "body mismatch: total=$total but blocks=$blocks keys=$keys user_answers=$uas"; return 1
  fi
  # The question bank is reference-only (it ships in the repo, answers included,
  # so anyone may have read it) — bank questions must never be served.
  if grep -qE '^(source: authored|id: seed-|id: ref-)' "$file"; then
    echo "bank questions are reference-only: found 'source: authored' / 'id: seed-*' in the exam"; return 1
  fi
  if [[ "$total" -eq 60 ]]; then
    if ! reason="$(check_composition_questions "$file")"; then echo "$reason"; return 1; fi
    if ! reason="$(check_key_spread "$file" payload)"; then echo "$reason"; return 1; fi
  fi
  return 0
}

validate_pair() {
  # Cross-file integrity of an on-disk attempt. Prints the reason on failure.
  local qt at blocks lines reason
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
  if grep -qE '^(source: authored|id: seed-|id: ref-)' "$EXAM_FILE"; then
    echo "bank questions are reference-only: found 'source: authored' / 'id: seed-*' in the exam"; return 1
  fi
  if [[ "$qt" -eq 60 ]]; then
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
  local i pairs=""
  for ((i = 0; i < ${#qs[@]}; i++)); do
    [[ "${qs[$i]}" =~ ^[0-9]+$ ]] || die "record: --q must be a question number (got '${qs[$i]}')"
    [[ "${answers[$i]}" =~ ^[A-D]$ ]] || die "record: --answer must be one of A B C D (got '${answers[$i]}')"
    pairs+="${qs[$i]}=${answers[$i]},"
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
  local d letter reason
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
  awk '
    /^[0-9]+ / {
      total++; dtotal[$2]++
      if ($4 != "-" && $4 == $3) { correct++; dcorrect[$2]++ }
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
        printf "domain=%s correct=%d total=%d\n", d, dcorrect[d] + 0, dtotal[d] + 0
      }
    }
  ' "$ANSWERS_FILE"
  set_field status completed
}

cmd_clear() {
  acquire_lock
  rm -f "$EXAM_FILE" "$ANSWERS_FILE" "$WEB_ID_FILE"
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
