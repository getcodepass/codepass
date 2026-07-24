#!/usr/bin/env bash
# 30 files (~100 lines each) change in several places apiece across two directories (api/,
# db/) — far past what one careful pass covers — and the run passes NO flag: fleet must
# self-activate on the coverage criterion alone. One guaranteed-crash bug is planted in each
# cluster. Invariants: the report declares fleet ran (the no-spawn fallback and single-pass
# both omit the line and fail this), both clusters' bugs are found (the coverage fleet exists
# to buy), and High findings force REQUEST_CHANGES.
# Cost: one fleet run = the main review PLUS one real model run per sub-agent, over a large
# fixture — the most expensive scenario in the suite.
# Not exercised: --fleet forcing a small diff, --no-fleet, PR-mode fleet, and whether fleet
# beats single-pass on recall (invariants can't judge finding quality — issue #5).
set -euo pipefail
EVAL_TIMEOUT_SECS="${EVAL_TIMEOUT_SECS:-600}"       # fan-out is slower than one pass
EVAL_BUDGET_USD="${EVAL_BUDGET_USD:-6}"             # main run + sub-agents, large fixture
EVAL_EXTRA_TOOLS="${EVAL_EXTRA_TOOLS:-Agent Task}"  # sub-agent spawning (Task = legacy name)
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

# gen_module <path> <prefix> <rev> — ten ~9-line functions; rev 2 rewrites every even one,
# so each file contributes several benign refactor hunks to the diff.
gen_module() {
  local path="$1" prefix="$2" rev="$3" j
  : > "$path"
  for j in $(seq 1 10); do
    if [ "$rev" = 2 ] && [ $((j % 2)) -eq 0 ]; then
      printf 'def %s_%d(x, y):\n    """%s case %d, revised."""\n    total = x + y * %d\n    if total < 0:\n        total = 0\n    result = total * 2\n    return result\n\n\n' \
        "$prefix" "$j" "$prefix" "$j" "$j" >> "$path"
    else
      printf 'def %s_%d(x, y):\n    """%s case %d."""\n    total = x + y * %d\n    if total < 0:\n        total = 0\n    return total * 2\n\n\n' \
        "$prefix" "$j" "$prefix" "$j" "$j" >> "$path"
    fi
  done
}

init_fixture
mkdir -p "$FIXTURE/api" "$FIXTURE/db"
for i in $(seq 1 14); do
  gen_module "$FIXTURE/api/handler_$i.py" "handle$i" 1
  gen_module "$FIXTURE/db/query_$i.py" "query$i" 1
done
cat > "$FIXTURE/api/auth.py" <<'EOF'
def check_token(token, valid_tokens):
    """Return True when the token is known."""
    return token in valid_tokens


def normalize(token):
    """Strip whitespace and lowercase."""
    return token.strip().lower()
EOF
cat > "$FIXTURE/db/stats.py" <<'EOF'
def average(values):
    """Mean of a non-empty list."""
    return sum(values) / len(values)


def spread(values):
    """Max minus min of a non-empty list."""
    return max(values) - min(values)
EOF
fixture_commit "initial" api db

# Every file changes (five refactor hunks each); the two real defects — one per cluster —
# are undefined names that crash on every call.
for i in $(seq 1 14); do
  gen_module "$FIXTURE/api/handler_$i.py" "handle$i" 2
  gen_module "$FIXTURE/db/query_$i.py" "query$i" 2
done
cat > "$FIXTURE/api/auth.py" <<'EOF'
def check_token(token, valid_tokens):
    """Return True when the token is known."""
    return tokn in valid_tokens


def normalize(token):
    """Strip whitespace and lowercase."""
    return token.strip().lower()
EOF
cat > "$FIXTURE/db/stats.py" <<'EOF'
def average(values):
    """Mean of a non-empty list."""
    total = sum(values)
    return total / len(value)


def spread(values):
    """Max minus min of a non-empty list."""
    return max(values) - min(values)
EOF

run_review

assert_matches "Fleet.*sub-agent" "fleet self-activated with no flag (report declares it)"
assert_finding "Critical|High" "auth\.py" "the api-cluster bug is found"
assert_finding "Critical|High" "stats\.py" "the db-cluster bug is found"
assert_matches "Disposition:.*REQUEST_CHANGES" "High findings force REQUEST_CHANGES"
finish
