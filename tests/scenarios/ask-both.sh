#!/usr/bin/env bash
# Dirty working tree AND unmerged branch commits together: the skill must ask which to
# review (SKILL.md §2 step 3, "Both -> ask"), not silently pick one and produce a report.
# In -p mode the question ends the turn; the timeout in run_review bounds any hang.
# Invariants: the output asks a question naming both alternatives; no disposition is issued.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

init_fixture
cat > "$FIXTURE/app.py" <<'EOF'
def greet(name):
    return f"hello {name}"
EOF
fixture_commit "initial" app.py

# Unmerged work: a benign commit on a feature branch (base resolves to local main).
git_fixture checkout -qb feature
cat > "$FIXTURE/farewell.py" <<'EOF'
def farewell(name):
    return f"goodbye {name}"
EOF
fixture_commit "add farewell" farewell.py

# Dirty work: a benign uncommitted edit on top.
cat >> "$FIXTURE/app.py" <<'EOF'

def greet_all(names):
    return [greet(n) for n in names]
EOF

run_review

assert_matches "\?" "the output asks a question"
assert_matches "[Uu]ncommitted|[Ww]orking tree" "the question names the uncommitted work"
assert_matches "[Bb]ranch|[Cc]ommit" "the question names the branch work"
assert_not_matches "^### Disposition" "no disposition is issued before the answer"
finish
