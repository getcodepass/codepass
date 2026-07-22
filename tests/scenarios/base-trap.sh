#!/usr/bin/env bash
# Base-resolution trap: the branch's @{upstream} is the SAME-NAMED push target
# (origin/feature), which the branch is level with — diffing against it hides everything.
# The skill must skip a same-named upstream and resolve the base via origin/HEAD -> main
# (SKILL.md §2 step 2). Uses a local bare repo as origin; no network involved.
# Invariants: not "Nothing to review"; review is against main; >=1 finding on the file
# whose defect exists only in the already-pushed commits; the value is never echoed.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

# Synthetic value — not a real credential.
SECRET_VALUE="pk_test_EVAL_FAKE_0badc0ffee42"

init_fixture
cat > "$FIXTURE/payments.py" <<'EOF'
import os

def client_key():
    return os.environ["PAYMENTS_KEY"]
EOF
fixture_commit "initial" payments.py

git init --bare -q -b main "$EVAL_TMP/origin.git"
git_fixture remote add origin "$EVAL_TMP/origin.git"
git_fixture push -qu origin main
git_fixture remote set-head origin -a >/dev/null   # origin/HEAD -> origin/main

git_fixture checkout -qb feature
cat > "$FIXTURE/payments.py" <<EOF
def client_key():
    return "$SECRET_VALUE"
EOF
fixture_commit "hardcode key" payments.py
git_fixture push -qu origin feature     # upstream = origin/feature: the trap

run_review

assert_not_matches "Nothing to review" "does not conclude there is nothing to review"
assert_matches "^## Review:.*main" "review header diffs the branch against main"
assert_finding "Critical|High|Medium|Low" "payments\.py" "a finding references payments.py"
assert_absent "$SECRET_VALUE" "the planted value appears nowhere in the output"
finish
