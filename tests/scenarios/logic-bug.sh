#!/usr/bin/env bash
# Planted logic bug (guaranteed IndexError) in an uncommitted change.
# Invariants: >=1 High-or-worse bug-risk finding referencing the file; disposition
# REQUEST_CHANGES (>= High, SKILL.md §7 — "logic bugs that will fail" are High).
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

init_fixture
cat > "$FIXTURE/items.py" <<'EOF'
def get_last(items):
    if not items:
        return None
    return items[-1]
EOF
fixture_commit "initial" items.py

# The change breaks last-element access: items[len(items)] raises IndexError on every call.
cat > "$FIXTURE/items.py" <<'EOF'
def get_last(items):
    if not items:
        return None
    return items[len(items)]
EOF

run_review

assert_finding "Critical|High" "items\.py" "a High-or-worse finding references items.py"
assert_matches "Disposition:.*REQUEST_CHANGES" "disposition is REQUEST_CHANGES"
finish
