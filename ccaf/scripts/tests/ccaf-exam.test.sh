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
# For n=60 the body matches the blueprint composition init now enforces: domain
# quotas 16/11/12/12/9, 4 scenarios (cycling) each with a [[CASE:]] block, keys
# cycling A-D (15 each). For other n: domains cycle D1..D5, key = A for all.
SCENARIOS=(customer-support code-generation multi-agent-research claude-code-ci)
LETTERS=(A B C D)
exam_domain() { # question index -> domain (quota blocks for 60, cycle otherwise)
  local n="$1" i="$2"
  if (( n == 60 )); then
    if   (( i <= 16 )); then echo "D1"
    elif (( i <= 27 )); then echo "D2"
    elif (( i <= 39 )); then echo "D3"
    elif (( i <= 51 )); then echo "D4"
    else                     echo "D5"; fi
  else
    echo "D$(( (i - 1) % 5 + 1 ))"
  fi
}
make_exam() {
  local n="$1" m_correct="$2" status="${3:-in_progress}" fill="${4:-blank}"
  { echo "---"; echo "status: $status"; echo "total: $n"
    echo "scenarios: ${SCENARIOS[0]},${SCENARIOS[1]},${SCENARIOS[2]},${SCENARIOS[3]}"
    echo "next_index: 1"; echo "---"
    local i ua dom key scen
    for ((i = 1; i <= n; i++)); do
      dom="$(exam_domain "$n" "$i")"
      if (( n == 60 )); then
        key="${LETTERS[$(( (i - 1) % 4 ))]}"
        # Contiguous case-study sections of 15, each headed by its case block.
        scen="${SCENARIOS[$(( (i - 1) / 15 ))]}"
        if (( (i - 1) % 15 == 0 )); then
          echo "[[CASE:$scen]]"; echo "title: $scen case"; echo "brief: synthetic case-study brief for $scen"
        fi
      else
        key="A"; scen="code-generation"
      fi
      if (( i <= m_correct )); then ua="$key"
      elif [[ "$fill" == "wrong" ]]; then
        if (( n == 60 )); then ua="${LETTERS[$(( i % 4 ))]}"; else ua="B"; fi   # never equals key
      else ua=""; fi
      echo "[[Q$i]]"; echo "domain: $dom"; echo "scenario: $scen"
      echo "source: generated"; echo "id: gen-$i"; echo "stem: question $i"
      echo "A) a"; echo "B) b"; echo "C) c"; echo "D) d"
      echo "answer_key: $key"; echo "user_answer: $ua"
    done
  } | bash "$HELPER" init --force >/dev/null
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
assert_eq "failed records leave next_index untouched" "1" "$(field next_index)"
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
if printf -- '---\nstatus: in_progress\ntotal: 1\nscenarios: a\nnext_index: 1\n---\n[[Q1]]\ndomain: D1\nscenario: a\nsource: generated\nid: g1\nstem: s\nA) a\nB) b\nC) c\nD) d\nanswer_key: A\nuser_answer:\n' | bash "$HELPER" init >/dev/null 2>&1; then
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
if printf -- '---\nstatus: in_progress\ntotal: 3\nscenarios: a\nnext_index: 1\n---\n[[Q1]]\ndomain: D1\nscenario: a\nsource: generated\nid: g1\nstem: s\nA) a\nB) b\nC) c\nD) d\nanswer_key: A\nuser_answer:\n' | bash "$HELPER" init >/dev/null 2>&1; then
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
if printf -- '---\nstatus: in_progress\ntotal: 1\nscenarios: a\nnext_index: 1\n---\n[[Q1]]\ndomain: D1\nscenario: a\nsource: authored\nid: seed-01\nstem: s\nA) a\nB) b\nC) c\nD) d\nanswer_key: A\nuser_answer:\n' | bash "$HELPER" init >/dev/null 2>&1; then
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
# Cycling domains gives 12 each — violates the 16/11/12/12/9 quota.
{ echo "---"; echo "status: in_progress"; echo "total: 60"
  echo "scenarios: customer-support,code-generation,multi-agent-research,claude-code-ci"
  echo "next_index: 1"; echo "---"
  for s in customer-support code-generation multi-agent-research claude-code-ci; do
    echo "[[CASE:$s]]"; echo "title: $s case"; echo "brief: b"
  done
  for ((i = 1; i <= 60; i++)); do
    echo "[[Q$i]]"; echo "domain: D$(( (i - 1) % 5 + 1 ))"
    echo "scenario: ${SCENARIOS[$(( (i - 1) % 4 ))]}"
    echo "source: generated"; echo "id: gen-$i"; echo "stem: q$i"
    echo "A) a"; echo "B) b"; echo "C) c"; echo "D) d"
    echo "answer_key: ${LETTERS[$(( (i - 1) % 4 ))]}"; echo "user_answer:"
  done
} | bash "$HELPER" init >/dev/null 2>&1
if [[ -f "$CCAF_EXAM_FILE" ]]; then
  echo "  FAIL: init should reject a 60-q exam violating domain quotas"; FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "  PASS: init rejects 60-q exam violating domain quotas"; PASS_COUNT=$((PASS_COUNT + 1))
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
{ echo "---"; echo "status: in_progress"; echo "total: 60"
  echo "scenarios: ${SCENARIOS[0]},${SCENARIOS[1]},${SCENARIOS[2]},${SCENARIOS[3]}"
  echo "next_index: 1"; echo "---"
  for s in "${SCENARIOS[@]}"; do
    echo "[[CASE:$s]]"; echo "title: $s case"; echo "brief: b"
  done
  for ((i = 1; i <= 60; i++)); do
    echo "[[Q$i]]"; echo "domain: $(exam_domain 60 "$i")"
    echo "scenario: ${SCENARIOS[$(( (i - 1) / 15 ))]}"
    echo "source: generated"; echo "id: gen-$i"; echo "stem: q$i"
    echo "A) a"; echo "B) b"; echo "C) c"; echo "D) d"
    echo "answer_key: ${LETTERS[$(( (i - 1) % 4 ))]}"; echo "user_answer:"
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
assert_contains "audit shows key spread" "$AUDIT" "key=A count=15"
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
printf -- '---\r\nstatus: in_progress\r\ntotal: 1\r\nscenarios: a\r\nnext_index: 1\r\n---\r\n[[Q1]]\r\ndomain: D1\r\nscenario: a\r\nsource: generated\r\nid: g1\r\nstem: s\r\nA) a\r\nB) b\r\nC) c\r\nD) d\r\nanswer_key: A\r\nuser_answer:\r\n' | bash "$HELPER" init >/dev/null
assert_eq "CRLF: status readable"            "in_progress" "$(field status)"
assert_eq "CRLF: blank answer stays blank"   "1"           "$(field next_index)"
bash "$HELPER" record --q 1 --answer A >/dev/null
assert_eq "CRLF: record + recompute works"   "2"           "$(field next_index)"
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
