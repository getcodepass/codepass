#!/usr/bin/env bash
# 24 tiny files change across two directories (api/, db/) — past the >20-file triage point —
# and the run is invoked with --fleet. One guaranteed-crash bug is planted in each cluster.
# Invariants: the report declares fleet ran (sub-agents actually spawned — the no-spawn
# fallback omits the line and fails this), both clusters' bugs are found (the coverage fleet
# exists to buy), and High findings force REQUEST_CHANGES.
# Cost: one fleet run = the main review PLUS one real model run per sub-agent (~2 here).
# Not exercised: PR-mode fleet, and whether fleet beats single-pass on recall — these files
# trivially fit one context, so this guards the mechanics, not the recall claim.
set -euo pipefail
EVAL_TIMEOUT_SECS="${EVAL_TIMEOUT_SECS:-600}"       # fan-out is slower than one pass
EVAL_BUDGET_USD="${EVAL_BUDGET_USD:-4}"             # main run + sub-agents
EVAL_EXTRA_TOOLS="${EVAL_EXTRA_TOOLS:-Agent Task}"  # sub-agent spawning (Task = legacy name)
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

init_fixture
mkdir -p "$FIXTURE/api" "$FIXTURE/db"
for i in $(seq 1 11); do
  printf 'def handle_%d(x):\n    """Handle case %d."""\n    return x + %d\n' "$i" "$i" "$i" \
    > "$FIXTURE/api/handler_$i.py"
  printf 'def query_%d(x):\n    """Query case %d."""\n    return x * %d\n' "$i" "$i" "$i" \
    > "$FIXTURE/db/query_$i.py"
done
cat > "$FIXTURE/api/auth.py" <<'EOF'
def check_token(token, valid_tokens):
    """Return True when the token is known."""
    return token in valid_tokens
EOF
cat > "$FIXTURE/db/stats.py" <<'EOF'
def average(values):
    """Mean of a non-empty list."""
    return sum(values) / len(values)
EOF
fixture_commit "initial" api db

# All 24 files change (docstring touch) so the diff passes the >20 triage point; the two real
# defects — one per cluster — are undefined names that crash on every call.
for i in $(seq 1 11); do
  printf 'def handle_%d(x):\n    """Handle case %d (rev 2)."""\n    return x + %d\n' "$i" "$i" "$i" \
    > "$FIXTURE/api/handler_$i.py"
  printf 'def query_%d(x):\n    """Query case %d (rev 2)."""\n    return x * %d\n' "$i" "$i" "$i" \
    > "$FIXTURE/db/query_$i.py"
done
cat > "$FIXTURE/api/auth.py" <<'EOF'
def check_token(token, valid_tokens):
    """Return True when the token is known."""
    return tokn in valid_tokens
EOF
cat > "$FIXTURE/db/stats.py" <<'EOF'
def average(values):
    """Mean of a non-empty list."""
    total = sum(values)
    return total / len(value)
EOF

run_review "/codepass:pr-review --fleet"

assert_matches "Fleet.*sub-agent" "report declares fleet ran (not the no-spawn fallback)"
assert_finding "Critical|High" "auth\.py" "the api-cluster bug is found"
assert_finding "Critical|High" "stats\.py" "the db-cluster bug is found"
assert_matches "Disposition:.*REQUEST_CHANGES" "High findings force REQUEST_CHANGES"
finish
