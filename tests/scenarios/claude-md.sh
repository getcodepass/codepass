#!/usr/bin/env bash
# The fixture repo has its own CLAUDE.md rule; the uncommitted diff breaks it.
# Invariants: >=1 finding citing CLAUDE.md (the convention source must be named) and
# referencing the offending file; disposition is not APPROVE.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

init_fixture
cat > "$FIXTURE/CLAUDE.md" <<'EOF'
# CLAUDE.md

## Conventions

- Never call `print()` in library code — always use the `logging` module.
EOF
cat > "$FIXTURE/metrics.py" <<'EOF'
import logging

logger = logging.getLogger(__name__)

def record(name, value):
    logger.info("metric %s=%s", name, value)
EOF
fixture_commit "initial" CLAUDE.md metrics.py

# The change swaps the logger for print(), violating the committed rule.
cat > "$FIXTURE/metrics.py" <<'EOF'
def record(name, value):
    print(f"metric {name}={value}")
EOF

run_review

assert_finding "Critical|High|Medium|Low" "metrics\.py" "a finding references metrics.py"
assert_matches "^\|[^|]*\|[^|]*\|.*CLAUDE\.md" "a findings-table row cites CLAUDE.md"
assert_not_matches "Disposition:.*APPROVE" "disposition is not APPROVE"
finish
