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

PASS_COUNT=0
FAIL_COUNT=0
WORK=""

setup() { WORK="$(mktemp -d)"; export CCAF_EXAM_FILE="$WORK/ccaf-exam.local.md"; }
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
# Domains cycle D1..D5; answer_key = A for all; user_answer = A for the first M.
make_exam() {
  local n="$1" m_correct="$2" status="${3:-in_progress}"
  { echo "---"; echo "status: $status"; echo "total: $n"
    echo "scenarios: customer-support,code-generation,multi-agent-research,claude-code-ci"
    echo "next_index: 1"; echo "---"
    local i ua dom
    for ((i = 1; i <= n; i++)); do
      dom="D$(( (i - 1) % 5 + 1 ))"
      if (( i <= m_correct )); then ua="A"; else ua=""; fi
      echo "[[Q$i]]"; echo "domain: $dom"; echo "scenario: code-generation"
      echo "source: generated"; echo "stem: question $i"
      echo "A) a"; echo "B) b"; echo "C) c"; echo "D) d"
      echo "answer_key: A"; echo "user_answer: $ua"
    done
  } | bash "$HELPER" init >/dev/null
}

field() { bash "$HELPER" get --field "$1"; }
score_field() { bash "$HELPER" score | grep -m1 "^$1=" | sed "s/^$1=//"; }

echo "== Slice 5.1: data files =="
assert_file_exists "blueprint exists" "$BLUEPRINT"
assert_file_exists "question bank exists" "$BANK"
assert_eq "12 seed questions"            "12" "$(grep -c '^  - id:' "$BANK")"
assert_eq "12 correct keys"              "12" "$(grep -cE '^    correct: [A-D]$' "$BANK")"
assert_eq "12 source: authored tags"     "12" "$(grep -cE '^    source: authored$' "$BANK")"
assert_eq "12 domain tags"               "12" "$(grep -cE '^    domain: D[1-5]$' "$BANK")"
assert_eq "12 scenario tags"             "12" "$(grep -cE '^    scenario: [a-z-]+$' "$BANK")"
# Domain weights in the blueprint sum to 60.
WEIGHTSUM="$(grep -oE '\| [0-9]+ +\|$' "$BLUEPRINT" | grep -oE '[0-9]+' | awk '{s+=$1} END{print s}')"
assert_eq "domain weights sum to 60"     "60" "$WEIGHTSUM"
assert_contains "blueprint names 720 pass" "$(cat "$BLUEPRINT")" "pass = 720"
assert_contains "blueprint has out-of-scope list" "$(cat "$BLUEPRINT")" "Out-of-scope topics"

echo "== Slice 5.2: init + get =="
setup
make_exam 4 0
assert_file_exists "exam file written" "$CCAF_EXAM_FILE"
assert_eq "status in_progress"  "in_progress" "$(field status)"
assert_eq "total persisted"     "4"           "$(field total)"
assert_eq "next_index starts 1" "1"           "$(field next_index)"
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
setup; make_exam 60 0
assert_eq "0/60 -> scaled 100"   "100"  "$(score_field scaled)"
assert_eq "0/60 -> FAIL"         "FAIL" "$(score_field verdict)"
teardown
setup; make_exam 60 42
assert_eq "42/60 -> scaled 730 (boundary)" "730"  "$(score_field scaled)"
assert_eq "42/60 -> PASS"                  "PASS" "$(score_field verdict)"
teardown
setup; make_exam 60 41
assert_eq "41/60 -> scaled 715 (just under)" "715"  "$(score_field scaled)"
assert_eq "41/60 -> FAIL"                    "FAIL" "$(score_field verdict)"
teardown

echo "== Slice 5.4: unanswered counts as incorrect =="
setup; make_exam 10 0   # all blank
# answer 5 correctly; 5 remain blank -> correct=5
for q in 1 2 3 4 5; do bash "$HELPER" record --q "$q" --answer A >/dev/null; done
assert_eq "5 answered, 5 blank -> correct=5/10" "correct=5/10" "$(bash "$HELPER" score | grep -m1 '^correct=')"
teardown

echo "== Slice 5.4: per-domain breakdown =="
setup; make_exam 10 10   # domains cycle D1..D5 -> each domain has 2 questions, all correct
assert_contains "D1 2/2" "$(bash "$HELPER" score)" "domain=D1 correct=2 total=2"
assert_contains "D5 2/2" "$(bash "$HELPER" score)" "domain=D5 correct=2 total=2"
teardown

echo "== Slice 5.4: score marks completed =="
setup; make_exam 4 4
bash "$HELPER" score >/dev/null
assert_eq "status -> completed" "completed" "$(field status)"
teardown

echo "== Slice 5.6: clear removes the file =="
setup; make_exam 4 0
bash "$HELPER" clear >/dev/null
if [[ -f "$CCAF_EXAM_FILE" ]]; then
  echo "  FAIL: clear removed file"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: clear removed file"; PASS_COUNT=$((PASS_COUNT + 1))
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
