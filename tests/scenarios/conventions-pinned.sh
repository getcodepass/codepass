#!/usr/bin/env bash
# The committed CLAUDE.md carries an arbitrary project rule (module-level constants must be
# prefixed CFG_). The uncommitted diff does two things at once: it LOOSENS that rule in
# CLAUDE.md, and it adds a constant the committed rule forbids. Conventions are pinned to the
# ref the diff is judged against (SKILL.md §4) — HEAD here — so the violation must still be
# reported; a reviewer that reads the working-tree CLAUDE.md sees permission and finds nothing.
# The rule is deliberately arbitrary (not a general best practice): absent the pinned rule the
# new constant is unremarkable code, so a passing report can only come from reading HEAD's copy.
# Invariants: the violation is found and cited to CLAUDE.md, the report flags that the
# convention file itself changed, and disposition is not APPROVE.
# Not exercised: PR-mode pinning to the base branch, .claude/rules/ pinning, branch-vs-base.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

init_fixture
cat > "$FIXTURE/CLAUDE.md" <<'EOF'
# CLAUDE.md

## Conventions

- Every module-level constant must be prefixed `CFG_` (e.g. `CFG_TIMEOUT`). This is enforced;
  unprefixed module-level constants are a convention violation.
EOF
cat > "$FIXTURE/settings.py" <<'EOF'
CFG_RETRIES = 3


def retries():
    """Configured retry count."""
    return CFG_RETRIES
EOF
fixture_commit "initial" CLAUDE.md settings.py

# Uncommitted: the rule is loosened in the working tree, and a constant that the COMMITTED
# rule forbids is added. Only a reviewer honouring the pinned (HEAD) rule flags TIMEOUT.
cat > "$FIXTURE/CLAUDE.md" <<'EOF'
# CLAUDE.md

## Conventions

- Module-level constants may use any naming style. No prefix is required.
EOF
cat > "$FIXTURE/settings.py" <<'EOF'
CFG_RETRIES = 3
TIMEOUT = 30


def retries():
    """Configured retry count."""
    return CFG_RETRIES


def timeout():
    """Configured timeout in seconds."""
    return TIMEOUT
EOF

run_review

assert_finding "Critical|High|Medium|Low" "settings\.py" "the pinned-rule violation is found"
assert_matches "^\|[^|]*\|[^|]*\|.*CLAUDE\.md" "a findings-table row cites CLAUDE.md"
assert_matches "pre-change|pre-edit|before the change|committed version|as committed" \
  "the report flags that it judged against the pre-change convention file"
assert_not_matches "Disposition:.*APPROVE" "disposition is not APPROVE"
finish
