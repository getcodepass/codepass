#!/usr/bin/env bash
# The fixture repo has a CLAUDE.md rule and a .claude/rules/ rule; the uncommitted diff breaks
# both. Invariants: findings reference both offending files, and the findings table cites each
# convention source by name (CLAUDE.md and the rules file). Disposition is not APPROVE.
# Not exercised: paths:-scoped rules (the planted rule is unconditional).
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

init_fixture
cat > "$FIXTURE/CLAUDE.md" <<'EOF'
# CLAUDE.md

## Conventions

- Never call `print()` in library code — always use the `logging` module.
EOF
mkdir -p "$FIXTURE/.claude/rules"
cat > "$FIXTURE/.claude/rules/errors.md" <<'EOF'
# Error handling rules

- Never use a bare `except:` — always catch specific exception types.
EOF
cat > "$FIXTURE/metrics.py" <<'EOF'
import logging

logger = logging.getLogger(__name__)

def record(name, value):
    logger.info("metric %s=%s", name, value)
EOF
cat > "$FIXTURE/fetch.py" <<'EOF'
import urllib.error
import urllib.request

def fetch(url):
    try:
        return urllib.request.urlopen(url).read()
    except urllib.error.URLError:
        return None
EOF
fixture_commit "initial" CLAUDE.md .claude/rules/errors.md metrics.py fetch.py

# The changes swap the logger for print() (CLAUDE.md violation) and widen the except
# to a bare one (.claude/rules/errors.md violation).
cat > "$FIXTURE/metrics.py" <<'EOF'
def record(name, value):
    print(f"metric {name}={value}")
EOF
cat > "$FIXTURE/fetch.py" <<'EOF'
import urllib.request

def fetch(url):
    try:
        return urllib.request.urlopen(url).read()
    except:
        return None
EOF

run_review

assert_finding "Critical|High|Medium|Low" "metrics\.py" "a finding references metrics.py"
assert_finding "Critical|High|Medium|Low" "fetch\.py" "a finding references fetch.py"
assert_matches "^\|[^|]*\|[^|]*\|.*CLAUDE\.md" "a findings-table row cites CLAUDE.md"
assert_matches "^\|[^|]*\|[^|]*\|.*errors\.md" "a findings-table row cites the rules file"
assert_not_matches "Disposition:.*APPROVE" "disposition is not APPROVE"
finish
