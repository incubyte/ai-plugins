#!/usr/bin/env bash
set -uo pipefail

# Tests for the /ccaf:mock-exam mock-exam build:
#  - data files (slice 5.1): blueprint + seed bank structure
#  - ccaf-exam.sh state helper (slices 5.2-5.6): init/get/record/score/clear,
#    next_index advancement (resume), and the scaled-score math.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DATA_DIR="$(cd "$SCRIPTS_DIR/../data" && pwd)"
HELPER="$SCRIPTS_DIR/ccaf-exam.sh"
BLUEPRINT="$DATA_DIR/ccaf-blueprint.md"
BANK="$DATA_DIR/ccaf-question-bank.md"
PREP_GUIDE="$DATA_DIR/ccaf-prep-guide.md"

PASS_COUNT=0
FAIL_COUNT=0
WORK=""

setup() {
  WORK="$(mktemp -d)"
  export CCAF_EXAM_FILE="$WORK/ccaf-exam.local.md"
  ANS_FILE="${CCAF_EXAM_FILE%.md}.answers.md"   # mirrors the helper's derivation
}
teardown() { [[ -n "$WORK" && -d "$WORK" ]] && rm -rf "$WORK"; }

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"; PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL: $label (expected '$expected', got '$actual')"; FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}
assert_file_exists() {
  local label="$1" path="$2"
  if [[ -f "$path" ]]; then echo "  PASS: $label"; PASS_COUNT=$((PASS_COUNT + 1))
  else echo "  FAIL: $label (not found: $path)"; FAIL_COUNT=$((FAIL_COUNT + 1)); fi
}
assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then echo "  PASS: $label"; PASS_COUNT=$((PASS_COUNT + 1))
  else echo "  FAIL: $label (missing '$needle')"; FAIL_COUNT=$((FAIL_COUNT + 1)); fi
}

# --- Builds a synthetic exam file: N questions, first M answered correctly. ---
# fill (4th arg): what the remaining questions get — "blank" (default) or "wrong".
# For n=60 the body matches the blueprint composition init enforces: domain
# quotas 16/11/12/12/9, 4 scenarios (cycling) each with a [[CASE:]] block, 45
# multiple-choice items whose keys cycle A-D, and 15 multiple-response items (4
# of them choose-three). For other n: domains cycle D1..D5, every item is
# single-select with key A.
SCENARIOS=(customer-support code-generation multi-agent-research claude-code-ci)
LETTERS=(A B C D)
PAIR_KEYS=(AB AC AD BC BD CD)
TRIPLE_KEYS=(ABC ABD ACD BCD)
# Sets DOM, SEL, KEY and WRONG for question $2 of an $1-item exam. Out-params
# rather than a subshell per field: this runs 60 times per fixture and there are
# ~15 fixtures per run, and process creation is slow enough on some machines
# (Windows + AV) that subshells here dominate the suite's wall-clock.
# Every 4th item is multiple-response; every i%16==8 item is choose-three. Over
# 60 that is 11 choose-two + 4 choose-three = 15, matching the blueprint.
DOM=D1
TASK=D1.1
SEL=1
KEY=A
WRONG=B
# Task statements published per domain, so the fixture only ever tags an item
# with one that exists (the helper rejects D2.6, for instance).
declare -A TASK_COUNT=([D1]=7 [D2]=5 [D3]=6 [D4]=6 [D5]=6)
exam_item() {
  local n="$1" i="$2" single
  if (( n == 60 )); then
    if   (( i <= 16 )); then DOM=D1
    elif (( i <= 27 )); then DOM=D2
    elif (( i <= 39 )); then DOM=D3
    elif (( i <= 51 )); then DOM=D4
    else                     DOM=D5; fi
    if (( i % 16 == 8 )); then
      SEL=3; KEY="${TRIPLE_KEYS[$(( (i / 16) % 4 ))]}"
    elif (( i % 4 == 0 )); then
      SEL=2; KEY="${PAIR_KEYS[$(( (i / 4) % 6 ))]}"
    else
      SEL=1
      single=$(( (i - 1) - (i - 1) / 4 ))   # how many single-select items precede i
      KEY="${LETTERS[$(( single % 4 ))]}"
    fi
  else
    DOM="D$(( (i - 1) % 5 + 1 ))"; SEL=1; KEY=A
  fi
  # Cycle through the domain's real task statements so items spread across them.
  TASK="$DOM.$(( i % TASK_COUNT[$DOM] + 1 ))"
  # WRONG is an answer guaranteed not to equal KEY. Under-selecting a
  # multiple-response item is wrong (all-or-nothing scoring), and a one-letter
  # answer can never equal a two- or three-letter key.
  if (( ${#KEY} > 1 )); then
    WRONG="${KEY:0:1}"
  else
    case "$KEY" in A) WRONG=B ;; B) WRONG=C ;; C) WRONG=D ;; *) WRONG=A ;; esac
  fi
}
make_exam() {
  local n="$1" m_correct="$2" status="${3:-in_progress}" fill="${4:-blank}"
  { echo "---"; echo "status: $status"; echo "total: $n"
    echo "scenarios: ${SCENARIOS[0]},${SCENARIOS[1]},${SCENARIOS[2]},${SCENARIOS[3]}"
    echo "next_index: 1"; echo "---"
    local i ua scen
    for ((i = 1; i <= n; i++)); do
      exam_item "$n" "$i"
      if (( n == 60 )); then
        # Contiguous case-study sections of 15, each headed by its case block.
        scen="${SCENARIOS[$(( (i - 1) / 15 ))]}"
        if (( (i - 1) % 15 == 0 )); then
          echo "[[CASE:$scen]]"; echo "title: $scen case"; echo "brief: synthetic case-study brief for $scen"
        fi
      else
        scen="code-generation"
      fi
      if (( i <= m_correct )); then ua="$KEY"
      elif [[ "$fill" == "wrong" ]]; then ua="$WRONG"
      else ua=""; fi
      echo "[[Q$i]]"; echo "domain: $DOM"; echo "task: $TASK"; echo "scenario: $scen"
      echo "source: generated"; echo "id: gen-$i"; echo "select: $SEL"; echo "stem: question $i"
      echo "A) a"; echo "B) b"; echo "C) c"; echo "D) d"
      echo "answer_key: $KEY"; echo "user_answer: $ua"
    done
  } | bash "$HELPER" init --force >/dev/null
}
# One question block for a hand-built payload, so a test can vary exactly one
# field (select, answer_key) and leave everything else well-formed.
item_block() { # index domain scenario select answer_key [task]
  # task defaults to <domain>.1, which always exists, so a test that is varying
  # some other field never trips the task/domain check by accident.
  local task="${6:-$2.1}"
  printf '[[Q%s]]\ndomain: %s\n' "$1" "$2"
  [[ "$task" == "omit" ]] || printf 'task: %s\n' "$task"
  printf 'scenario: %s\nsource: generated\nid: gen-%s\n' "$3" "$1"
  [[ "$4" == "omit" ]] || printf 'select: %s\n' "$4"
  printf 'stem: question %s\nA) a\nB) b\nC) c\nD) d\nanswer_key: %s\nuser_answer:\n' "$1" "$5"
}
one_item_exam() { # select answer_key [task] -> pipes a 1-question payload into init
  { printf -- '---\nstatus: in_progress\ntotal: 1\nscenarios: code-generation\nnext_index: 1\n---\n'
    printf '[[CASE:code-generation]]\ntitle: c\nbrief: b\n'
    item_block 1 D1 code-generation "$1" "$2" "${3:-D1.1}"
  } | bash "$HELPER" init >/dev/null 2>&1
}

field() { bash "$HELPER" get --field "$1"; }
score_field() { bash "$HELPER" score | grep -m1 "^$1=" | sed "s/^$1=//"; }

echo "== Slice 5.1: data files =="
assert_file_exists "blueprint exists" "$BLUEPRINT"
assert_file_exists "question bank exists" "$BANK"
assert_file_exists "prep guide exists" "$PREP_GUIDE"
BANK_QUESTIONS="$(grep -c '^  - id:' "$BANK")"
assert_eq "every bank question has a correct key" "$BANK_QUESTIONS" "$(grep -cE '^    correct: [A-D]{1,3}$' "$BANK")"
assert_eq "every bank question is source: authored" "$BANK_QUESTIONS" "$(grep -cE '^    source: authored$' "$BANK")"
assert_eq "every bank question has a domain tag" "$BANK_QUESTIONS" "$(grep -cE '^    domain: D[1-5]$' "$BANK")"
assert_eq "every bank question has a task statement tag" "$BANK_QUESTIONS" "$(grep -cE '^    task: D[1-5]\.[1-7]$' "$BANK")"
assert_eq "every bank question has a scenario tag" "$BANK_QUESTIONS" "$(grep -cE '^    scenario: [a-z-]+$' "$BANK")"
assert_eq "every bank question declares a select count" "$BANK_QUESTIONS" "$(grep -cE '^    select: [1-3]$' "$BANK")"
# The bank must anchor both item formats, or generated multiple-response items
# have no style reference to follow.
MULTI_ANCHORS="$(grep -cE '^    select: [23]$' "$BANK")"
if [[ "$MULTI_ANCHORS" -ge 3 ]]; then
  echo "  PASS: bank anchors multiple-response items ($MULTI_ANCHORS of $BANK_QUESTIONS)"; PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  FAIL: bank needs at least 3 multiple-response anchors (found $MULTI_ANCHORS)"; FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# A multi-letter key must name distinct letters in A-D order, matching what the
# helper accepts — otherwise the anchors teach a shape init would reject.
BAD_ANCHOR_KEYS="$(grep -E '^    correct: [A-D]{2,3}$' "$BANK" | sed 's/^    correct: //' |
  awk '{ for (i = 2; i <= length($0); i++) if (substr($0, i, 1) <= substr($0, i-1, 1)) { print; next } }' | wc -l | tr -d '[:space:]')"
assert_eq "multi-letter anchor keys are sorted and distinct" "0" "$BAD_ANCHOR_KEYS"
# Domain weights in the blueprint sum to 60.
WEIGHTSUM="$(grep -oE '\| [0-9]+ +\|$' "$BLUEPRINT" | grep -oE '[0-9]+' | awk '{s+=$1} END{print s}')"
assert_eq "domain weights sum to 60"     "60" "$WEIGHTSUM"
assert_contains "blueprint names 720 pass" "$(cat "$BLUEPRINT")" "pass = 720"
assert_contains "blueprint has out-of-scope list" "$(cat "$BLUEPRINT")" "Out-of-scope topics"
assert_contains "blueprint states the multiple-response share" "$(cat "$BLUEPRINT")" "15 of 60 items"
assert_contains "blueprint names the exam code" "$(cat "$BLUEPRINT")" "CCAR-F"

echo "== Slice 5.2: init + get (split files) =="
setup
make_exam 4 0
assert_file_exists "questions file written" "$CCAF_EXAM_FILE"
assert_file_exists "answers file written"   "$ANS_FILE"
assert_eq "status in_progress"  "in_progress" "$(field status)"
assert_eq "total persisted"     "4"           "$(field total)"
assert_eq "next_index starts 1" "1"           "$(field next_index)"
assert_eq "questions file holds no answer keys" "0" "$(grep -c '^answer_key:' "$CCAF_EXAM_FILE" || true)"
assert_eq "questions file holds no user answers" "0" "$(grep -c '^user_answer:' "$CCAF_EXAM_FILE" || true)"
assert_eq "get output is key-free" "0" "$(bash "$HELPER" get | grep -c '^answer_key:' || true)"
# The skill reads select: to know how many responses a screen collects, so it has
# to survive into the key-free questions file.
assert_eq "questions file keeps select counts" "4" "$(grep -c '^select: ' "$CCAF_EXAM_FILE" || true)"
teardown

echo "== Slice 5.3 + 5.5: record advances next_index (resume cursor) =="
setup
make_exam 4 0
bash "$HELPER" record --q 1 --answer A >/dev/null
assert_eq "after Q1, next_index=2" "2" "$(field next_index)"
bash "$HELPER" record --q 2 --answer B >/dev/null
assert_eq "after Q2, next_index=3" "3" "$(field next_index)"
# Answer out of order: Q4 then next_index still points at the first gap (Q3).
bash "$HELPER" record --q 4 --answer C >/dev/null
assert_eq "gap at Q3 -> next_index=3" "3" "$(field next_index)"
bash "$HELPER" record --q 3 --answer D >/dev/null
assert_eq "all answered -> next_index=total+1" "5" "$(field next_index)"
teardown

echo "== Slice 5.4: scoring math =="
setup; make_exam 60 60
assert_eq "60/60 -> scaled 1000" "1000" "$(score_field scaled)"
assert_eq "60/60 -> PASS"        "PASS" "$(score_field verdict)"
teardown
setup; make_exam 60 0 in_progress wrong
assert_eq "0/60 -> scaled 100"   "100"  "$(score_field scaled)"
assert_eq "0/60 -> FAIL"         "FAIL" "$(score_field verdict)"
teardown
setup; make_exam 60 42 in_progress wrong
assert_eq "42/60 -> scaled 730 (boundary)" "730"  "$(score_field scaled)"
assert_eq "42/60 -> PASS"                  "PASS" "$(score_field verdict)"
teardown
setup; make_exam 60 41 in_progress wrong
assert_eq "41/60 -> scaled 715 (just under)" "715"  "$(score_field scaled)"
assert_eq "41/60 -> FAIL"                    "FAIL" "$(score_field verdict)"
teardown

echo "== Slice 5.4: unanswered counts as incorrect (score --partial) =="
setup; make_exam 10 0   # all blank
# answer 5 correctly; 5 remain blank -> correct=5 via --partial
for q in 1 2 3 4 5; do bash "$HELPER" record --q "$q" --answer A >/dev/null; done
assert_eq "5 answered, 5 blank -> correct=5/10" "correct=5/10" "$(bash "$HELPER" score --partial | grep -m1 '^correct=')"
teardown

echo "== Guards: score refuses blanks without --partial =="
setup; make_exam 10 3   # 7 blank
if bash "$HELPER" score >/dev/null 2>&1; then
  echo "  FAIL: score should refuse an incomplete exam without --partial"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: score refuses incomplete exam without --partial"; PASS_COUNT=$((PASS_COUNT + 1))
fi
assert_eq "refused score leaves status in_progress" "in_progress" "$(field status)"
teardown

echo "== Guards: score refuses a truncated/corrupt file =="
setup; make_exam 4 4
# Corrupt: claim 60 questions while only 4 blocks exist.
sed -i.bak 's/^total: 4$/total: 60/' "$CCAF_EXAM_FILE" && rm -f "$CCAF_EXAM_FILE.bak"
if bash "$HELPER" score >/dev/null 2>&1; then
  echo "  FAIL: score should refuse when block count != total"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: score refuses truncated file (blocks != total)"; PASS_COUNT=$((PASS_COUNT + 1))
fi
teardown

echo "== Guards: record input validation =="
setup; make_exam 4 0
if bash "$HELPER" record --q junk --answer A >/dev/null 2>&1; then
  echo "  FAIL: record should reject non-numeric --q"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: record rejects non-numeric --q"; PASS_COUNT=$((PASS_COUNT + 1))
fi
if bash "$HELPER" record --q 1 --answer E >/dev/null 2>&1; then
  echo "  FAIL: record should reject answer E"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: record rejects answer outside A-D"; PASS_COUNT=$((PASS_COUNT + 1))
fi
if bash "$HELPER" record --q 99 --answer A >/dev/null 2>&1; then
  echo "  FAIL: record should fail for a nonexistent question"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: record fails for nonexistent question"; PASS_COUNT=$((PASS_COUNT + 1))
fi
for bad in ABCD AE ""; do
  if bash "$HELPER" record --q 1 --answer "$bad" >/dev/null 2>&1; then
    echo "  FAIL: record should reject answer set '$bad'"; FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    echo "  PASS: record rejects answer set '$bad'"; PASS_COUNT=$((PASS_COUNT + 1))
  fi
done
assert_eq "failed records leave next_index untouched" "1" "$(field next_index)"
teardown

echo "== Multiple-response: an answer set is recorded order-insensitively =="
setup; make_exam 60 0
# Q4 is a choose-two item; submit its two letters lowercased and reversed.
bash "$HELPER" record --q 4 --answer ca >/dev/null
assert_eq "'ca' normalizes to AC" "AC" "$(awk '$1 == 4 { print $4 }' "$ANS_FILE")"
assert_eq "recording out of order leaves next_index at the first gap" "1" "$(field next_index)"
teardown

echo "== Multiple-response: scoring is all-or-nothing =="
setup; make_exam 60 0
# Q4's key names two letters. One of them right is not partial credit.
bash "$HELPER" record --q 4 --answer A >/dev/null
assert_eq "half-right choose-two scores zero" "correct=0/60" "$(bash "$HELPER" score --partial | grep -m1 '^correct=')"
teardown
setup; make_exam 60 0
bash "$HELPER" record --q 4 --answer AC >/dev/null
assert_eq "the exact choose-two set scores one" "correct=1/60" "$(bash "$HELPER" score --partial | grep -m1 '^correct=')"
teardown
setup; make_exam 60 0
# Q8 is a choose-three item; over-selecting is wrong too.
bash "$HELPER" record --q 8 --answer ABCD >/dev/null 2>&1 || true
bash "$HELPER" record --q 8 --answer ABD >/dev/null
assert_eq "a wrong choose-three set scores zero" "correct=0/60" "$(bash "$HELPER" score --partial | grep -m1 '^correct=')"
teardown
setup; make_exam 60 0
bash "$HELPER" record --q 8 --answer CBA >/dev/null
assert_eq "the exact choose-three set scores one" "correct=1/60" "$(bash "$HELPER" score --partial | grep -m1 '^correct=')"
teardown

echo "== Guards: init rejects an item whose select count disagrees with its key =="
setup
one_item_exam 2 A
if [[ -f "$CCAF_EXAM_FILE" ]]; then
  echo "  FAIL: select: 2 with a one-letter key must be rejected"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: select: 2 with a one-letter key is rejected"; PASS_COUNT=$((PASS_COUNT + 1))
fi
teardown
setup
one_item_exam 1 AC
if [[ -f "$CCAF_EXAM_FILE" ]]; then
  echo "  FAIL: select: 1 with a two-letter key must be rejected"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: select: 1 with a two-letter key is rejected"; PASS_COUNT=$((PASS_COUNT + 1))
fi
teardown

echo "== Guards: init rejects malformed answer keys and missing select counts =="
for bad_key in CA AA AE ABCD; do
  setup
  one_item_exam "${#bad_key}" "$bad_key"
  if [[ -f "$CCAF_EXAM_FILE" ]]; then
    echo "  FAIL: answer_key '$bad_key' must be rejected"; FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    echo "  PASS: answer_key '$bad_key' is rejected"; PASS_COUNT=$((PASS_COUNT + 1))
  fi
  teardown
done
setup
one_item_exam omit A
if [[ -f "$CCAF_EXAM_FILE" ]]; then
  echo "  FAIL: a question block with no select: line must be rejected"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: a question block with no select: line is rejected"; PASS_COUNT=$((PASS_COUNT + 1))
fi
teardown
setup
one_item_exam 1 A
assert_file_exists "a well-formed single-item exam is accepted" "$CCAF_EXAM_FILE"
teardown

echo "== Guards: init rejects an unsorted pre-filled user_answer =="
setup
# Scoring is exact string comparison, so an unsorted "DB" would score a correct
# "BD" answer as wrong. Reject it at the boundary rather than mis-score later.
{ printf -- '---\nstatus: in_progress\ntotal: 1\nscenarios: code-generation\nnext_index: 1\n---\n'
  printf '[[CASE:code-generation]]\ntitle: c\nbrief: b\n'
  printf '[[Q1]]\ndomain: D1\ntask: D1.1\nscenario: code-generation\nsource: generated\nid: gen-1\nselect: 2\n'
  printf 'stem: question 1\nA) a\nB) b\nC) c\nD) d\nanswer_key: BD\nuser_answer: DB\n'
} | bash "$HELPER" init >/dev/null 2>&1
if [[ -f "$CCAF_EXAM_FILE" ]]; then
  echo "  FAIL: an unsorted user_answer must be rejected"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: an unsorted user_answer is rejected"; PASS_COUNT=$((PASS_COUNT + 1))
fi
teardown
setup
# Under-selecting a multiple-response item IS a legitimate wrong answer, so a
# shorter-than-select user_answer must still be accepted.
{ printf -- '---\nstatus: in_progress\ntotal: 1\nscenarios: code-generation\nnext_index: 1\n---\n'
  printf '[[CASE:code-generation]]\ntitle: c\nbrief: b\n'
  printf '[[Q1]]\ndomain: D1\ntask: D1.1\nscenario: code-generation\nsource: generated\nid: gen-1\nselect: 2\n'
  printf 'stem: question 1\nA) a\nB) b\nC) c\nD) d\nanswer_key: BD\nuser_answer: B\n'
} | bash "$HELPER" init >/dev/null 2>&1
assert_file_exists "an under-selected user_answer is accepted" "$CCAF_EXAM_FILE"
assert_eq "the under-selection scores as incorrect" "correct=0/1" "$(bash "$HELPER" score | grep -m1 '^correct=')"
teardown

echo "== Guards: init rejects a task statement that cannot be right =="
# A mistagged item sends a candidate to study the wrong objective, so the tag is
# validated rather than trusted: it must exist, and belong to the item's domain.
for bad_task in D2.1 D1.9 D1 X1.1 omit; do
  setup
  one_item_exam 1 A "$bad_task"   # the item block declares domain: D1
  if [[ -f "$CCAF_EXAM_FILE" ]]; then
    echo "  FAIL: task '$bad_task' on a D1 item must be rejected"; FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    echo "  PASS: task '$bad_task' on a D1 item is rejected"; PASS_COUNT=$((PASS_COUNT + 1))
  fi
  teardown
done
setup
one_item_exam 1 A D1.7   # D1 publishes seven task statements, so D1.7 exists
assert_file_exists "the last task statement in a domain is accepted" "$CCAF_EXAM_FILE"
teardown

echo "== Score: misses are attributed to the task statement, not just the domain =="
setup; make_exam 10 10   # every item correct; D2.3 is tagged on two of them
SCORED="$(bash "$HELPER" score)"
assert_contains "a repeated task statement aggregates" "$SCORED" "task=D2.3 correct=2 total=2"
assert_contains "a single-item task statement reports" "$SCORED" "task=D1.2 correct=1 total=1"
teardown
setup; make_exam 10 1 in_progress wrong   # only Q1 (task D1.2) is correct
SCORED="$(bash "$HELPER" score)"
assert_contains "an all-missed task statement reports 0" "$SCORED" "task=D2.3 correct=0 total=2"
assert_contains "the one correct task statement reports 1" "$SCORED" "task=D1.2 correct=1 total=1"
teardown

echo "== Guards: a select count drifting from its key is caught on the pair =="
setup; make_exam 60 60
# Flip one choose-two item's select count to 1 without touching its key.
sed -i.bak '0,/^select: 2$/s//select: 1/' "$CCAF_EXAM_FILE" && rm -f "$CCAF_EXAM_FILE.bak"
if bash "$HELPER" score >/dev/null 2>&1; then
  echo "  FAIL: a select count that disagrees with its key should fail validation"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: a select count that disagrees with its key fails validation"; PASS_COUNT=$((PASS_COUNT + 1))
fi
teardown

echo "== Guards: record refuses a completed attempt =="
setup; make_exam 4 4
bash "$HELPER" score >/dev/null
if bash "$HELPER" record --q 1 --answer B >/dev/null 2>&1; then
  echo "  FAIL: record should refuse a completed attempt"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: record refuses a completed attempt"; PASS_COUNT=$((PASS_COUNT + 1))
fi
teardown

echo "== Guards: init refuses to overwrite an in-progress attempt =="
setup; make_exam 4 2
if printf -- '---\nstatus: in_progress\ntotal: 1\nscenarios: a\nnext_index: 1\n---\n[[Q1]]\ndomain: D1\nscenario: a\nsource: generated\nid: g1\nselect: 1\nstem: s\nA) a\nB) b\nC) c\nD) d\nanswer_key: A\nuser_answer:\n' | bash "$HELPER" init >/dev/null 2>&1; then
  echo "  FAIL: init should refuse to clobber an in-progress attempt"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: init refuses to clobber an in-progress attempt"; PASS_COUNT=$((PASS_COUNT + 1))
fi
assert_eq "original attempt intact after refused init" "4" "$(field total)"
make_exam 2 0   # uses init --force -> allowed to replace
assert_eq "init --force replaces the attempt" "2" "$(field total)"
teardown

echo "== Guards: init rejects a malformed body =="
setup
if printf -- '---\nstatus: in_progress\ntotal: 3\nscenarios: a\nnext_index: 1\n---\n[[Q1]]\ndomain: D1\nscenario: a\nsource: generated\nid: g1\nselect: 1\nstem: s\nA) a\nB) b\nC) c\nD) d\nanswer_key: A\nuser_answer:\n' | bash "$HELPER" init >/dev/null 2>&1; then
  echo "  FAIL: init should reject body with blocks != total"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: init rejects body with blocks != total"; PASS_COUNT=$((PASS_COUNT + 1))
fi
if [[ -f "$CCAF_EXAM_FILE" || -f "$ANS_FILE" ]]; then
  echo "  FAIL: rejected init must write neither file"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: rejected init writes neither file"; PASS_COUNT=$((PASS_COUNT + 1))
fi
teardown

echo "== Reference bank: bank questions are never served =="
setup
if printf -- '---\nstatus: in_progress\ntotal: 1\nscenarios: a\nnext_index: 1\n---\n[[Q1]]\ndomain: D1\nscenario: a\nsource: authored\nid: seed-01\nselect: 1\nstem: s\nA) a\nB) b\nC) c\nD) d\nanswer_key: A\nuser_answer:\n' | bash "$HELPER" init >/dev/null 2>&1; then
  echo "  FAIL: init must reject source: authored / id: seed-* blocks"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: init rejects bank questions (source: authored / id: seed-*)"; PASS_COUNT=$((PASS_COUNT + 1))
fi
if [[ -f "$CCAF_EXAM_FILE" || -f "$ANS_FILE" ]]; then
  echo "  FAIL: rejected bank-question init must write nothing"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: rejected bank-question init writes nothing"; PASS_COUNT=$((PASS_COUNT + 1))
fi
teardown

echo "== Split files: record touches only the answers file =="
setup; make_exam 8 0
cp "$CCAF_EXAM_FILE" "$WORK/questions.before"
bash "$HELPER" record --q 1 --answer A --q 2 --answer B >/dev/null
if cmp -s "$CCAF_EXAM_FILE" "$WORK/questions.before"; then
  echo "  PASS: questions file is byte-identical after record"; PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  FAIL: record must never rewrite the questions file"; FAIL_COUNT=$((FAIL_COUNT + 1))
fi
assert_eq "answers recorded in answers file" "2" "$(grep -cE '^[0-9]+ D[1-5] [A-D] [A-D]$' "$ANS_FILE" || true)"
teardown

echo "== Split files: blanks lists unanswered question numbers =="
setup; make_exam 4 1
assert_eq "blanks -> 2 3 4" "2 3 4" "$(bash "$HELPER" blanks | tr '\n' ' ' | sed 's/ $//')"
bash "$HELPER" record --q 3 --answer C >/dev/null
assert_eq "blanks shrinks after record" "2 4" "$(bash "$HELPER" blanks | tr '\n' ' ' | sed 's/ $//')"
teardown

echo "== Perf: batched record (one call per screen) =="
setup; make_exam 8 0
bash "$HELPER" record --q 1 --answer A --q 2 --answer B --q 3 --answer C --q 4 --answer D >/dev/null
assert_eq "batch of 4 advances next_index to 5" "5" "$(field next_index)"
# Atomicity: one bad question number in the batch -> nothing is recorded.
if bash "$HELPER" record --q 5 --answer A --q 99 --answer B >/dev/null 2>&1; then
  echo "  FAIL: batch with a missing question should fail"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: batch with a missing question fails"; PASS_COUNT=$((PASS_COUNT + 1))
fi
assert_eq "failed batch records nothing (Q5 still blank)" "5" "$(field next_index)"
teardown

echo "== Perf: concurrent records serialize via the state lock =="
setup; make_exam 8 0
bash "$HELPER" record --q 1 --answer A --q 2 --answer B >/dev/null &
bash "$HELPER" record --q 3 --answer C --q 4 --answer D >/dev/null &
wait
assert_eq "both concurrent batches landed" "5" "$(field next_index)"
if [[ -d "$CCAF_EXAM_FILE.lock" ]]; then
  echo "  FAIL: lock should be released after records finish"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: lock released after records finish"; PASS_COUNT=$((PASS_COUNT + 1))
fi
teardown

echo "== Perf: a stale lock is stolen, not a deadlock =="
setup; make_exam 4 0
mkdir "$CCAF_EXAM_FILE.lock"   # simulate a crashed holder
CCAF_LOCK_WAIT_ITERS=6 bash "$HELPER" record --q 1 --answer A >/dev/null
assert_eq "stale lock stolen and record landed" "2" "$(field next_index)"
teardown

echo "== Composition: init enforces blueprint quotas on 60-question exams =="
setup
# Cycling domains gives 12 each — violates the 16/11/12/12/9 quota. Everything
# else (select mix, case sections, key spread) is well-formed, so the quota rule
# is what rejects this.
{ echo "---"; echo "status: in_progress"; echo "total: 60"
  echo "scenarios: ${SCENARIOS[0]},${SCENARIOS[1]},${SCENARIOS[2]},${SCENARIOS[3]}"
  echo "next_index: 1"; echo "---"
  for ((i = 1; i <= 60; i++)); do
    exam_item 60 "$i"
    if (( (i - 1) % 15 == 0 )); then
      s="${SCENARIOS[$(( (i - 1) / 15 ))]}"
      echo "[[CASE:$s]]"; echo "title: $s case"; echo "brief: b"
    fi
    # Task tag follows the (deliberately wrong) cycling domain, so the quota rule
    # is what rejects this rather than the task/domain check firing first.
    wrongdom="D$(( (i - 1) % 5 + 1 ))"
    item_block "$i" "$wrongdom" "${SCENARIOS[$(( (i - 1) / 15 ))]}" "$SEL" "$KEY" "$wrongdom.1"
  done
} | bash "$HELPER" init >/dev/null 2>&1
if [[ -f "$CCAF_EXAM_FILE" ]]; then
  echo "  FAIL: init should reject a 60-q exam violating domain quotas"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: init rejects 60-q exam violating domain quotas"; PASS_COUNT=$((PASS_COUNT + 1))
fi
teardown

echo "== Composition: init enforces the multiple-response share on 60-question exams =="
setup
# Domains, scenarios, and case sections are all correct; every item is
# single-select, so the exam has 0 multiple-response items instead of 15.
{ echo "---"; echo "status: in_progress"; echo "total: 60"
  echo "scenarios: ${SCENARIOS[0]},${SCENARIOS[1]},${SCENARIOS[2]},${SCENARIOS[3]}"
  echo "next_index: 1"; echo "---"
  for ((i = 1; i <= 60; i++)); do
    exam_item 60 "$i"
    if (( (i - 1) % 15 == 0 )); then
      s="${SCENARIOS[$(( (i - 1) / 15 ))]}"
      echo "[[CASE:$s]]"; echo "title: $s case"; echo "brief: b"
    fi
    item_block "$i" "$DOM" "${SCENARIOS[$(( (i - 1) / 15 ))]}" 1 "${LETTERS[$(( (i - 1) % 4 ))]}"
  done
} | bash "$HELPER" init >/dev/null 2>&1
if [[ -f "$CCAF_EXAM_FILE" ]]; then
  echo "  FAIL: init should reject an all-single-select 60-q exam"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: init rejects a 60-q exam with no multiple-response items"; PASS_COUNT=$((PASS_COUNT + 1))
fi
teardown

echo "== Composition: missing case block / biased keys are rejected =="
setup; make_exam 60 60
sed -i.bak '/^\[\[CASE:customer-support\]\]$/d' "$CCAF_EXAM_FILE" && rm -f "$CCAF_EXAM_FILE.bak"
if bash "$HELPER" score >/dev/null 2>&1; then
  echo "  FAIL: missing [[CASE:]] block should fail validation"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: missing [[CASE:]] block fails validation"; PASS_COUNT=$((PASS_COUNT + 1))
fi
teardown
setup; make_exam 60 60
# Keys now live in the answers file (column 3): turn every B key into A -> A=30, B=0.
sed -i.bak 's/^\([0-9][0-9]* D[1-5]\) B /\1 A /' "$ANS_FILE" && rm -f "$ANS_FILE.bak"
if bash "$HELPER" score >/dev/null 2>&1; then
  echo "  FAIL: degenerate key distribution should fail validation"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: degenerate key distribution fails validation"; PASS_COUNT=$((PASS_COUNT + 1))
fi
teardown

echo "== Composition: a question under the wrong case block is rejected =="
setup; make_exam 60 60
# Break section coherence: Q1 (under [[CASE:customer-support]]) gets another scenario.
sed -i.bak '0,/^scenario: customer-support$/s//scenario: code-generation/' "$CCAF_EXAM_FILE" && rm -f "$CCAF_EXAM_FILE.bak"
if bash "$HELPER" score >/dev/null 2>&1; then
  echo "  FAIL: question under mismatched case block should fail validation"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: question under mismatched case block fails validation"; PASS_COUNT=$((PASS_COUNT + 1))
fi
teardown

echo "== Composition: all case blocks up front (stale-brief layout) is rejected =="
setup
# Domains, select mix, and key spread are all valid — only the case-block layout
# is wrong, so that is what rejects this.
{ echo "---"; echo "status: in_progress"; echo "total: 60"
  echo "scenarios: ${SCENARIOS[0]},${SCENARIOS[1]},${SCENARIOS[2]},${SCENARIOS[3]}"
  echo "next_index: 1"; echo "---"
  for s in "${SCENARIOS[@]}"; do
    echo "[[CASE:$s]]"; echo "title: $s case"; echo "brief: b"
  done
  for ((i = 1; i <= 60; i++)); do
    exam_item 60 "$i"
    item_block "$i" "$DOM" "${SCENARIOS[$(( (i - 1) / 15 ))]}" "$SEL" "$KEY"
  done
} | bash "$HELPER" init >/dev/null 2>&1
if [[ -f "$CCAF_EXAM_FILE" ]]; then
  echo "  FAIL: case blocks must head their own sections, not sit up front"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: up-front case blocks (stale-brief layout) rejected"; PASS_COUNT=$((PASS_COUNT + 1))
fi
teardown

echo "== Composition: audit reports the histogram =="
setup; make_exam 60 0
AUDIT="$(bash "$HELPER" audit)"
assert_contains "audit shows D1=16"      "$AUDIT" "domain=D1 questions=16"
assert_contains "audit shows D2=11"      "$AUDIT" "domain=D2 questions=11"
assert_contains "audit shows D5=9"       "$AUDIT" "domain=D5 questions=9"
assert_contains "audit shows 45 multiple-choice" "$AUDIT" "select=1 questions=45"
assert_contains "audit shows 11 choose-two"      "$AUDIT" "select=2 questions=11"
assert_contains "audit shows 4 choose-three"     "$AUDIT" "select=3 questions=4"
assert_contains "audit shows key spread" "$AUDIT" "key=A count=12"
assert_contains "audit composition OK"   "$AUDIT" "composition=OK"
teardown

echo "== Composition: case blocks don't disturb record/score/resume =="
setup; make_exam 60 0
bash "$HELPER" record --q 1 --answer A --q 2 --answer A >/dev/null   # Q1 key=A (right), Q2 key=B (wrong)
assert_eq "record works alongside CASE blocks" "3" "$(field next_index)"
assert_eq "score --partial works alongside CASE blocks" "correct=1/60" "$(bash "$HELPER" score --partial | grep -m1 '^correct=')"
teardown

echo "== Guards: CRLF input is normalized on init =="
setup
printf -- '---\r\nstatus: in_progress\r\ntotal: 1\r\nscenarios: a\r\nnext_index: 1\r\n---\r\n[[Q1]]\r\ndomain: D1\r\ntask: D1.1\r\nscenario: a\r\nsource: generated\r\nid: g1\r\nselect: 1\r\nstem: s\r\nA) a\r\nB) b\r\nC) c\r\nD) d\r\nanswer_key: A\r\nuser_answer:\r\n' | bash "$HELPER" init >/dev/null
assert_eq "CRLF: status readable"            "in_progress" "$(field status)"
assert_eq "CRLF: blank answer stays blank"   "1"           "$(field next_index)"
bash "$HELPER" record --q 1 --answer A >/dev/null
assert_eq "CRLF: record + recompute works"   "2"           "$(field next_index)"
teardown

echo "== Slice 5.4: per-domain breakdown, with the percent the real report shows =="
setup; make_exam 10 10   # domains cycle D1..D5 -> each domain has 2 questions, all correct
assert_contains "D1 2/2 at 100%" "$(bash "$HELPER" score)" "domain=D1 correct=2 total=2 pct=100"
assert_contains "D5 2/2 at 100%" "$(bash "$HELPER" score)" "domain=D5 correct=2 total=2 pct=100"
teardown
setup; make_exam 10 1 in_progress wrong   # Q1 correct, Q6 wrong -> D1 is 1 of 2
assert_contains "D1 1/2 rounds to 50%" "$(bash "$HELPER" score)" "domain=D1 correct=1 total=2 pct=50"
teardown

echo "== Slice 5.4: score marks completed =="
setup; make_exam 4 4
bash "$HELPER" score >/dev/null
assert_eq "status -> completed" "completed" "$(field status)"
teardown

echo "== Slice 5.6: clear removes both files =="
setup; make_exam 4 0
bash "$HELPER" clear >/dev/null
if [[ -f "$CCAF_EXAM_FILE" || -f "$ANS_FILE" ]]; then
  echo "  FAIL: clear must remove both attempt files"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: clear removed both attempt files"; PASS_COUNT=$((PASS_COUNT + 1))
fi
teardown

echo "== Slice 5.6: get on missing file fails gracefully =="
setup
if bash "$HELPER" get >/dev/null 2>&1; then
  echo "  FAIL: get should fail when no exam exists"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: get fails cleanly when no exam exists"; PASS_COUNT=$((PASS_COUNT + 1))
fi
teardown

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
[[ "$FAIL_COUNT" -eq 0 ]]
