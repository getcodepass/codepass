#!/usr/bin/env bash
# Clean diff: a docs-only wording tweak with nothing wrong.
# Guards the "don't invent findings" rule (SKILL.md §5).
# Invariants: zero findings-table rows; disposition APPROVE.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

init_fixture
cat > "$FIXTURE/README.md" <<'EOF'
# widget

A small library for building widgets.

## Usage

Import `widget` and call `widget.build()`.
EOF
cat > "$FIXTURE/widget.py" <<'EOF'
def build():
    return {"kind": "widget"}
EOF
fixture_commit "initial" README.md widget.py

# Benign uncommitted change: reword one README sentence. No code touched.
cat > "$FIXTURE/README.md" <<'EOF'
# widget

A small library for constructing widgets.

## Usage

Import `widget` and call `widget.build()`.
EOF

run_review

assert_not_matches "^\|[^|]*\| *(Critical|High|Medium|Low|Nitpick) *\|" "no findings-table rows"
assert_matches "Disposition:.*APPROVE" "disposition is APPROVE"
finish
