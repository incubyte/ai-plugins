#!/usr/bin/env bash
set -eo pipefail

# ccaf-exam.sh — Silent state persistence for the /ccaf:mock-exam mock exam.
#
# Called via Bash from the ccaf-exam skill to avoid Write/Edit permission prompts.
# Operates on a single per-attempt file (default ~/.claude/ccaf-exam.local.md;
# override with CCAF_EXAM_FILE, used by tests).
#
# Usage:
#   ccaf-exam.sh init [--force]       # read full exam body from stdin, validate, write the file
#                                     # (refuses to overwrite an in-progress attempt unless --force;
#                                     #  60-question exams must match the CCAF blueprint composition)
#   ccaf-exam.sh get                  # print the whole file
#   ccaf-exam.sh get --field status   # print one frontmatter field (status|next_index|total)
#   ccaf-exam.sh record --q 7 --answer C [--q 8 --answer A ...]
#                                     # record one or more answers in a single call (atomic),
#                                     # then advance next_index
#   ccaf-exam.sh audit                # print composition (total, scenarios, per-domain and
#                                     # per-key counts) + composition=OK|FAIL
#   ccaf-exam.sh score [--partial]    # tally + scaled score + per-domain; mark completed
#                                     # (refuses unanswered questions unless --partial)
#   ccaf-exam.sh clear                # remove the file
#
# Exam file format (frontmatter + one [[CASE:]] block per scenario section + one
# block per question; questions are grouped contiguously by scenario):
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

# Temp files live next to the exam file so the final rename is atomic — readers
# never observe a half-written file.
state_tmp() { mktemp "$(dirname "$EXAM_FILE")/.ccaf-exam.tmp.XXXXXX"; }

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
  tmp="$(state_tmp)"
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

count_blanks() {
  # Count questions with an empty user_answer.
  grep -cE '^user_answer:[[:space:]]*$' "$EXAM_FILE" || true
}

validate_exam_body() {
  # Structural integrity: total is numeric and the [[Qn]] / answer_key / user_answer
  # line counts all equal it. For the production 60-question exam, also enforces the
  # CCAF blueprint composition (domain quotas, 4 scenarios with case blocks, key spread).
  # Prints the reason on failure.
  local file="$1" total blocks keys uas
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

  if [[ "$total" -eq 60 ]]; then
    # Domain quotas: 27/18/20/20/15% of 60.
    local pair d want got
    for pair in D1=16 D2=11 D3=12 D4=12 D5=9; do
      d="${pair%%=*}"; want="${pair##*=}"
      got="$(grep -c "^domain: $d\$" "$file" || true)"
      [[ "$got" -eq "$want" ]] || { echo "domain $d has $got questions, blueprint requires $want"; return 1; }
    done
    # Exactly 4 distinct scenarios; each listed scenario has questions and a [[CASE:]] block.
    local scen_line scen_count s
    scen_line="$(read_field_from scenarios "$file")"
    scen_count="$(tr ',' '\n' <<<"$scen_line" | sed '/^$/d' | sort -u | wc -l | tr -d '[:space:]')"
    [[ "$scen_count" -eq 4 ]] || { echo "frontmatter lists $scen_count scenarios, need exactly 4"; return 1; }
    for s in ${scen_line//,/ }; do
      got="$(grep -c "^scenario: $s\$" "$file" || true)"
      [[ "$got" -ge 1 ]] || { echo "scenario $s is listed but has no questions"; return 1; }
      grep -q "^\[\[CASE:$s\]\]\$" "$file" || { echo "scenario $s is missing its [[CASE:$s]] case-study block"; return 1; }
    done
    # Every question's scenario must be one of the listed four.
    local bs
    while IFS= read -r bs; do
      [[ ",$scen_line," == *",$bs,"* ]] || { echo "question scenario '$bs' is not in the frontmatter scenario list"; return 1; }
    done < <(grep '^scenario: ' "$file" | sed 's/^scenario: //' | sort -u)
    # Case-study structure: each [[CASE:slug]] appears exactly once and directly
    # heads a contiguous run of its own questions — so the brief shown above a
    # screen always belongs to that screen's questions, never a previous case.
    local struct
    struct="$(awk '
      /^\[\[CASE:[a-z-]+\]\]$/ {
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
    # Answer-key spread: catch degenerate position bias (uniform random ≈ 15 each).
    local letter cnt
    for letter in A B C D; do
      cnt="$(grep -c "^answer_key: $letter\$" "$file" || true)"
      if [[ "$cnt" -lt 6 || "$cnt" -gt 26 ]]; then
        echo "answer key '$letter' appears $cnt/60 times — positions look biased (aim ~15 each); reshuffle"; return 1
      fi
    done
  fi
  return 0
}

cmd_init() {
  local force=0
  [[ "${1:-}" == "--force" ]] && force=1
  acquire_lock
  if [[ -f "$EXAM_FILE" && "$force" -eq 0 ]]; then
    local existing_status
    existing_status="$(read_field status)"
    [[ "$existing_status" == "in_progress" ]] && \
      die "init: an in-progress attempt exists at $EXAM_FILE — run 'clear' first or use 'init --force'"
  fi
  mkdir -p "$(dirname "$EXAM_FILE")"
  local tmp reason
  tmp="$(state_tmp)"
  tr -d '\r' > "$tmp"   # body from stdin; normalize CRLF so awk parsing is OS-independent
  if ! reason="$(validate_exam_body "$tmp")"; then
    rm -f "$tmp"
    die "init: malformed exam body ($reason) — file not written"
  fi
  mv "$tmp" "$EXAM_FILE"
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
  # Accepts one or more --q/--answer pairs and applies them in a single atomic
  # rewrite — one call per screen keeps administration fast.
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
    /^\[\[Q[0-9]+\]\]$/ {
      qn = $0; gsub(/[^0-9]/, "", qn); cur = qn + 0
    }
    /^user_answer:/ && (cur in ans) && !seen[cur]++ { print "user_answer: " ans[cur]; done++; next }
    { print }
    END { if (done != expected) exit 3 }
  ' "$EXAM_FILE" > "$tmp" || { rm -f "$tmp"; die "record: could not record all answers (a question number is missing or duplicated) — nothing was recorded"; }
  mv "$tmp" "$EXAM_FILE"
  recompute_next_index
  echo "Recorded ${#qs[@]} answer(s); next_index=$(read_field next_index)"
}

cmd_audit() {
  require_file
  local d letter reason
  echo "total=$(read_field total)"
  echo "scenarios=$(read_field scenarios)"
  for d in D1 D2 D3 D4 D5; do
    echo "domain=$d questions=$(grep -c "^domain: $d\$" "$EXAM_FILE" || true)"
  done
  for letter in A B C D; do
    echo "key=$letter count=$(grep -c "^answer_key: $letter\$" "$EXAM_FILE" || true)"
  done
  if reason="$(validate_exam_body "$EXAM_FILE")"; then
    echo "composition=OK"
  else
    echo "composition=FAIL ($reason)"
    return 1
  fi
}

cmd_score() {
  require_file
  acquire_lock
  local partial=0 reason blanks
  [[ "${1:-}" == "--partial" ]] && partial=1
  if ! reason="$(validate_exam_body "$EXAM_FILE")"; then
    die "score: exam file failed integrity check ($reason) — refusing to score"
  fi
  blanks="$(count_blanks)"
  if [[ "$partial" -eq 0 && "$blanks" -gt 0 ]]; then
    die "score: $blanks question(s) unanswered — use 'score --partial' to submit incomplete (blanks count as incorrect)"
  fi
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
  acquire_lock
  rm -f "$EXAM_FILE"
  echo "Exam cleared."
}

[[ $# -ge 1 ]] || die "usage: ccaf-exam.sh {init|get|record|score|clear} [...]"
command="$1"; shift
case "$command" in
  init)   cmd_init "$@" ;;
  get)    cmd_get "$@" ;;
  record) cmd_record "$@" ;;
  audit)  cmd_audit "$@" ;;
  score)  cmd_score "$@" ;;
  clear)  cmd_clear "$@" ;;
  *) die "unknown command: $command" ;;
esac
