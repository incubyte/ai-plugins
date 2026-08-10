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
#   options, and each item's `select:` count, but NO answer keys and NO user
#   answers. Safe to read and show during administration; recording never
#   rewrites it. `select:` stays here because the skill needs to know how many
#   responses an item wants without ever seeing which ones are correct.
#
#   Answers file (<questions-file minus .md>.answers.md) — small and hot:
#   status + next_index frontmatter, then one "qnum domain key user" line per
#   question ("-" = unanswered). Recording rewrites only this file, and the
#   skill never reads it during administration, so answer keys stay out of the
#   conversation.
#
# Item formats. An item is multiple-choice (`select: 1`, key is one letter) or
# multiple-response (`select: 2` or `3`, key is that many letters in A-D order).
# Multiple-response is scored all-or-nothing: the recorded set must equal the key
# exactly. Recorded answers are normalized to uppercase, sorted, de-duplicated,
# so selection order never affects the comparison.
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
#   ccaf-exam.sh record --q 7 --answer C [--q 8 --answer BD ...]
#                                     # record one or more answers in a single call
#                                     # (atomic), then advance next_index; an answer
#                                     # is 1-3 distinct letters from A-D
#   ccaf-exam.sh blanks               # unanswered question numbers, one per line
#   ccaf-exam.sh audit                # composition (total, scenarios, per-domain,
#                                     # per-select and per-key counts) +
#                                     # composition=OK|FAIL
#   ccaf-exam.sh score [--partial]    # tally + scaled score + per-domain correct and
#                                     # percent; mark completed (refuses unanswered
#                                     # questions unless --partial)
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
#   select: 1                    # 1 = multiple-choice; 2 or 3 = multiple-response
#   stem: ...
#   A) ...
#   B) ...
#   C) ...
#   D) ...
#   answer_key: A                # `select:` letters, in A-D order (e.g. "BD")
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
BLUEPRINT_MULTI_RESPONSE=15
BLUEPRINT_MAX_CHOOSE_THREE=5
MAX_SELECT=3

die() { echo "ccaf-exam: $*" >&2; exit 1; }

normalize_answer() {
  # "ca" -> "AC". Uppercased, sorted, de-duplicated, so a recorded answer set
  # compares equal to its key regardless of the order the candidate picked in.
  # Fails on anything that is not 1..MAX_SELECT letters drawn from A-D.
  # Deliberately pure bash: record runs once per exam screen, and spawning a
  # sort/tr pipeline per answer is a visible cost where process creation is slow.
  local raw="$1" i char letter upper="" out=""
  (( ${#raw} >= 1 && ${#raw} <= MAX_SELECT )) || return 1
  for (( i = 0; i < ${#raw}; i++ )); do
    char="${raw:i:1}"
    case "$char" in
      a | A) upper+=A ;;
      b | B) upper+=B ;;
      c | C) upper+=C ;;
      d | D) upper+=D ;;
      *) return 1 ;;
    esac
  done
  for letter in A B C D; do
    if [[ "$upper" == *"$letter"* ]]; then out+="$letter"; fi
  done
  printf '%s' "$out"
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
  # Per-item format integrity on an init payload: every question block carries a
  # `select:` count in 1..MAX_SELECT whose value equals the length of its
  # `answer_key`, and the key names distinct letters in A-D order. A pre-filled
  # `user_answer` is held to the same letter shape (though not to the same
  # length — under-selecting a multiple-response item is a legitimate wrong
  # answer), because scoring is exact string comparison: an unsorted "DB" would
  # score a correct "BD" answer as wrong. Prints the first offending question,
  # empty output when every item is well-formed.
  local file="$1"
  awk -v maxsel="$MAX_SELECT" '
    function ordered(letters, label,    i) {
      if (letters !~ /^[A-D]+$/) { print "Q" q " " label " " letters " must be letters A-D"; return 0 }
      for (i = 2; i <= length(letters); i++) {
        if (substr(letters, i, 1) <= substr(letters, i - 1, 1)) {
          print "Q" q " " label " " letters " must name distinct letters in A-D order"; return 0 }
      }
      return 1
    }
    /^\[\[Q[0-9]+\]\]$/ { q = $0; gsub(/[^0-9]/, "", q); sel = ""; next }
    /^select: /     { sel = $2; next }
    /^answer_key: / {
      key = $2
      if (sel == "")                     { print "Q" q " has no select: line"; exit }
      if (sel !~ /^[0-9]+$/ || sel + 0 < 1 || sel + 0 > maxsel) {
        print "Q" q " select: " sel " must be between 1 and " maxsel; exit }
      if (!ordered(key, "answer_key"))   { exit }
      if (length(key) != sel + 0)        { print "Q" q " select: " sel " but answer_key " key " names " length(key); exit }
      next
    }
    /^user_answer:/ {
      ua = $0; sub(/^user_answer:[[:space:]]*/, "", ua)
      if (ua == "") next
      if (length(ua) > maxsel)           { print "Q" q " user_answer " ua " names more than " maxsel " letters"; exit }
      if (!ordered(ua, "user_answer"))   { exit }
    }
  ' "$file"
}

check_composition_questions() {
  # Full-mock blueprint checks on the questions side: domain quotas, the
  # item-format mix, the scenario count, and contiguous case-headed sections
  # (each [[CASE:slug]] appears once and directly heads a run of its own
  # questions — so the brief shown above a screen always belongs to that
  # screen's questions, never a previous case). Also valid against an init
  # payload; the extra answer lines are ignored.
  #
  # One awk pass, not a dozen greps: this runs on every init and every score,
  # and process creation is expensive enough on some machines (Windows + AV)
  # that a per-check subprocess is the dominant cost. Structural problems are
  # recorded rather than reported immediately, so failures still surface in the
  # documented order — quotas, mix, scenarios, then layout.
  # Prints the reason on failure.
  local file="$1" reason
  reason="$(awk -v quotas="$BLUEPRINT_DOMAIN_QUOTAS" -v wantscen="$BLUEPRINT_SCENARIOS" \
                -v wantmulti="$BLUEPRINT_MULTI_RESPONSE" -v maxthree="$BLUEPRINT_MAX_CHOOSE_THREE" \
                -v maxsel="$MAX_SELECT" '
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
    /^select: /  { if ($2 + 0 > 1) multi++; if ($2 + 0 == maxsel) three++; next }
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
      if (multi + 0 != wantmulti) { printf "%d multiple-response items, blueprint requires %d\n", multi + 0, wantmulti; exit }
      if (three + 0 > maxthree)   { printf "%d choose-%d items, blueprint allows at most %d\n", three + 0, maxsel, maxthree; exit }
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
  # Catch degenerate answer-position bias among the multiple-choice items. Only
  # they have a single-letter key, so both counts below skip multiple-response
  # items for free. This is a guard against gross bias — all keys on one letter —
  # not a uniformity test; the assembling skill aims for an even spread.
  # mode "payload": read `answer_key:` lines; mode "answers": read column 3.
  local file="$1" mode="$2" reason
  reason="$(awk -v mode="$mode" '
    mode == "payload" && /^answer_key: [A-D]$/  { key[$2]++; single++ }
    mode == "answers" && /^[0-9]+ / && length($3) == 1 { key[$3]++; single++ }
    END {
      # Too few single-select items for a spread to mean anything.
      if (single < 8) exit
      lo = int(single / 10); hi = int(single / 2)
      n = split("A,B,C,D", letters, ",")
      for (i = 1; i <= n; i++) {
        L = letters[i]; c = key[L] + 0
        if (c < lo || c > hi) {
          printf "multiple-choice key %s appears %d/%d times — positions look biased (aim ~%d each); reshuffle\n", L, c, single, int(single / 4)
          exit
        }
      }
    }
  ' "$file")"
  [[ -z "$reason" ]] || { echo "$reason"; return 1; }
  return 0
}

check_select_alignment() {
  # Cross-file check: the questions file's `select:` counts must match the
  # answers file's key lengths. A screen reads `select:` to decide how many
  # responses to collect, so a drift here would ask for the wrong number.
  local reason
  reason="$(awk -v maxsel="$MAX_SELECT" '
    FNR == NR  { if ($0 ~ /^select: [0-9]+$/) want[$2 + 0]++; next }
    /^[0-9]+ / { got[length($3)]++ }
    END {
      for (n = 1; n <= maxsel; n++) {
        if (want[n] + 0 != got[n] + 0) {
          printf "%d question(s) ask for %d response(s) but %d answer key(s) name %d\n", want[n] + 0, n, got[n] + 0, n
          exit
        }
      }
    }
  ' "$EXAM_FILE" "$ANSWERS_FILE")"
  [[ -z "$reason" ]] || { echo "$reason"; return 1; }
  return 0
}

validate_payload() {
  # Structural integrity of an init payload: total is numeric and the [[Qn]] /
  # select / answer_key / user_answer line counts all equal it, and every item's
  # select count agrees with its key. For a full 60-item exam, also enforces the
  # CCAF blueprint composition. Prints the reason on failure.
  local file="$1" total blocks sels keys uas reason
  total="$(read_field_from total "$file")"
  if ! [[ "$total" =~ ^[0-9]+$ && "$total" -gt 0 ]]; then
    echo "frontmatter 'total' missing or non-numeric"; return 1
  fi
  blocks="$(grep -cE '^\[\[Q[0-9]+\]\]$' "$file" || true)"
  sels="$(grep -cE '^select:[[:space:]]*[0-9]+[[:space:]]*$' "$file" || true)"
  keys="$(grep -cE "^answer_key:[[:space:]]*[A-D]{1,$MAX_SELECT}[[:space:]]*\$" "$file" || true)"
  uas="$(grep -c '^user_answer:' "$file" || true)"
  if [[ "$blocks" -ne "$total" || "$sels" -ne "$total" || "$keys" -ne "$total" || "$uas" -ne "$total" ]]; then
    echo "body mismatch: total=$total but blocks=$blocks selects=$sels keys=$keys user_answers=$uas"; return 1
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
  local qt at blocks lines selects reason
  qt="$(read_field_from total "$EXAM_FILE")"
  at="$(read_field_from total "$ANSWERS_FILE")"
  if ! [[ "$qt" =~ ^[0-9]+$ && "$qt" -gt 0 ]]; then
    echo "questions file 'total' missing or non-numeric"; return 1
  fi
  [[ "$qt" == "$at" ]] || { echo "totals diverge: questions file says $qt, answers file says $at"; return 1; }
  blocks="$(grep -cE '^\[\[Q[0-9]+\]\]$' "$EXAM_FILE" || true)"
  [[ "$blocks" -eq "$qt" ]] || { echo "questions file has $blocks blocks but total=$qt"; return 1; }
  lines="$(grep -cE "^[0-9]+ D[1-5] [A-D]{1,$MAX_SELECT} ([A-D]{1,$MAX_SELECT}|-)\$" "$ANSWERS_FILE" || true)"
  [[ "$lines" -eq "$qt" ]] || { echo "answers file has $lines well-formed lines but total=$qt"; return 1; }
  selects="$(grep -cE '^select:[[:space:]]*[0-9]+[[:space:]]*$' "$EXAM_FILE" || true)"
  [[ "$selects" -eq "$qt" ]] || { echo "questions file has $selects select: lines but total=$qt"; return 1; }
  if ! reason="$(check_select_alignment)"; then echo "$reason"; return 1; fi
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
      die "record: --answer must be 1 to $MAX_SELECT distinct letters from A-D (got '${answers[$i]}')"
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
  for (( sel = 1; sel <= MAX_SELECT; sel++ )); do
    echo "select=$sel questions=$(grep -c "^select: $sel\$" "$EXAM_FILE" || true)"
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
    # A multiple-response item is all-or-nothing: both sides are normalized to
    # sorted distinct letters, so exact string equality IS set equality.
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
        pct = (dtotal[d] > 0) ? int(dcorrect[d] * 100 / dtotal[d] + 0.5) : 0
        printf "domain=%s correct=%d total=%d pct=%d\n", d, dcorrect[d] + 0, dtotal[d] + 0, pct
      }
    }
  ' "$ANSWERS_FILE"
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
