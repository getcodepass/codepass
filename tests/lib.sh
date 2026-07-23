#!/usr/bin/env bash
# Shared harness for codepass eval scenarios. Sourced by tests/scenarios/*.sh — not run directly.
#
# A scenario script:
#   1. sources this file (which creates a temp dir with an empty fixture repo path in $FIXTURE)
#   2. builds its fixture repo under "$FIXTURE"
#   3. calls run_review            → report captured in "$REPORT" (outside the repo, so the
#                                    review never sees its own output as an untracked file)
#   4. asserts invariants with the assert_* helpers (coarse greps, never exact output)
#   5. ends with finish            → prints check results, exits non-zero on any failed check

set -euo pipefail

EVAL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_DIR="$EVAL_ROOT/plugins/codepass"

# Knobs (env-overridable)
EVAL_TIMEOUT_SECS="${EVAL_TIMEOUT_SECS:-420}"   # wall clock per review; bounds interactive hangs
EVAL_BUDGET_USD="${EVAL_BUDGET_USD:-2}"         # --max-budget-usd per review
EVAL_MODEL="${EVAL_MODEL:-}"                    # optional --model override

SCENARIO_NAME="$(basename "${0%.sh}")"

# Everything lives in one mktemp dir under $TMPDIR, removed on exit — never fixed /tmp names.
_tmp="$(mktemp -d "${TMPDIR:-/tmp}/codepass-eval-${SCENARIO_NAME}.XXXXXX")"
trap 'rm -rf "$_tmp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
EVAL_TMP="$_tmp"        # scenarios may place extra pieces here (e.g. a bare "origin")
FIXTURE="$_tmp/repo"
REPORT="$_tmp/report.md"
STDERR_LOG="$_tmp/stderr.txt"
mkdir -p "$FIXTURE"
: > "$REPORT"
: > "$STDERR_LOG"

_pass=0
_fail=0

# ---- fixture helpers --------------------------------------------------------

git_fixture() { git -C "$FIXTURE" "$@"; }

init_fixture() {
  git_fixture init -q -b main
  git_fixture config user.email eval@example.invalid
  git_fixture config user.name "codepass eval"
}

# fixture_commit <message> <path>... — stage the named paths and commit.
fixture_commit() {
  local msg="$1"; shift
  git_fixture add -- "$@"
  git_fixture commit -qm "$msg"
}

# ---- invocation -------------------------------------------------------------

# macOS ships no `timeout`; fall back to perl's alarm (both kill the child on expiry).
with_timeout() {
  local secs="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
  else
    perl -e 'alarm shift; exec @ARGV' "$secs" "$@"
  fi
}

# run_review [prompt] — invoke the skill headlessly from inside $FIXTURE.
#   --plugin-dir            loads THIS checkout's plugin, so evals test the SKILL.md under edit
#   --setting-sources       project-only: user settings/plugins stay out (hermetic, and avoids
#                           colliding with a user-scope codepass install)
#   --permission-mode dontAsk + allowlist: read-only git and file reads only; anything else is
#                           denied instead of prompting (a prompt would hang -p forever)
#   Local-mode scenarios need no network: gh/curl are simply not allowlisted.
# Non-zero exit (e.g. timeout on a scenario that must ask) is recorded, not fatal — grading
# decides pass/fail from the captured output.
run_review() {
  local prompt="${1:-/codepass:pr-review}"
  local model_args=()
  if [ -n "$EVAL_MODEL" ]; then model_args=(--model "$EVAL_MODEL"); fi
  RUN_RC=0
  (
    cd "$FIXTURE" && with_timeout "$EVAL_TIMEOUT_SECS" \
      claude -p "$prompt" \
        --plugin-dir "$PLUGIN_DIR" \
        --setting-sources project \
        --permission-mode dontAsk \
        --allowedTools \
          "Bash(git status:*)" "Bash(git log:*)" "Bash(git diff:*)" \
          "Bash(git rev-parse:*)" "Bash(git merge-base:*)" "Bash(git symbolic-ref:*)" \
          "Bash(git branch:*)" "Bash(git show:*)" "Bash(git ls-files:*)" \
          "Bash(git remote:*)" "Bash(git for-each-ref:*)" "Bash(git cat-file:*)" \
          "Bash(git config --get:*)" \
          "Read" "Glob" "Grep" \
        --no-session-persistence \
        --max-budget-usd "$EVAL_BUDGET_USD" \
        ${model_args[@]+"${model_args[@]}"}
  ) >"$REPORT" 2>"$STDERR_LOG" || RUN_RC=$?
  if [ "$RUN_RC" -ne 0 ]; then
    echo "  note: claude exited $RUN_RC (a timeout kill reports 142 or 124)"
  fi
  return 0
}

# ---- grading ----------------------------------------------------------------

_check() { # <pass|fail> <description>
  if [ "$1" = pass ]; then
    _pass=$((_pass + 1)); printf '  ok   %s\n' "$2"
  else
    _fail=$((_fail + 1)); printf '  FAIL %s\n' "$2"
  fi
}

# assert_matches <ERE> <description> — some line of the report matches.
assert_matches() {
  if grep -Eq "$1" "$REPORT"; then _check pass "$2"
  else _check fail "$2  [no line matches: $1]"; fi
}

# assert_not_matches <ERE> <description> — no line of the report matches.
assert_not_matches() {
  if grep -Eq "$1" "$REPORT"; then _check fail "$2  [report matches: $1]"
  else _check pass "$2"; fi
}

# assert_absent <fixed-string> <description> — string appears nowhere in stdout OR stderr.
# Used for planted secret values: they must never be reproduced.
assert_absent() {
  if grep -Fq "$1" "$REPORT" "$STDERR_LOG"; then _check fail "$2  [value leaked into output]"
  else _check pass "$2"; fi
}

# assert_finding <sev-ERE> <file-ERE> <description> — a findings-table row whose severity
# column matches <sev-ERE> and whose line mentions <file-ERE>. Row shape per SKILL.md §8:
#   | 1 | Critical | app.py | 3 | ... | 97 |
assert_finding() {
  assert_matches "^\|[^|]*\| *(${1}) *\|.*${2}" "$3"
}

finish() {
  printf '%s: %d ok, %d failed\n' "$SCENARIO_NAME" "$_pass" "$_fail"
  if [ "$_fail" -gt 0 ]; then
    echo "--- captured report ---"
    sed -n '1,120p' "$REPORT"
    echo "--- captured stderr ---"
    sed -n '1,40p' "$STDERR_LOG"
    exit 1
  fi
  exit 0
}
