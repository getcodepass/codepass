#!/usr/bin/env bash
# Run the codepass eval scenarios headlessly and grade each report against its invariants.
#
#   tests/run-evals.sh              # all scenarios (one real claude run EACH — costs tokens)
#   tests/run-evals.sh secret       # a single scenario, for cheap iteration
#
# Exits non-zero if any scenario fails. See tests/README.md for cost notes and knobs.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
scenarios_dir="$here/scenarios"

usage() {
  echo "usage: $0 [scenario-name]"
  echo "available scenarios:"
  for f in "$scenarios_dir"/*.sh; do
    echo "  $(basename "${f%.sh}")"
  done
}

if [ $# -gt 1 ]; then
  usage >&2
  exit 2
fi

scenarios=()
if [ $# -eq 1 ]; then
  case "$1" in
    -h|--help) usage; exit 0 ;;
  esac
  if [ ! -f "$scenarios_dir/$1.sh" ]; then
    echo "unknown scenario: $1" >&2
    usage >&2
    exit 2
  fi
  scenarios=("$scenarios_dir/$1.sh")
else
  for f in "$scenarios_dir"/*.sh; do
    scenarios+=("$f")
  done
fi

results=""
failures=0
for s in "${scenarios[@]}"; do
  name="$(basename "${s%.sh}")"
  echo "=== $name ==="
  if bash "$s"; then
    results="${results}${name}|PASS
"
  else
    results="${results}${name}|FAIL
"
    failures=$((failures + 1))
  fi
  echo
done

echo "=== results ==="
printf '%-12s %s\n' "scenario" "result"
printf '%-12s %s\n' "--------" "------"
printf '%s' "$results" | while IFS='|' read -r name result; do
  printf '%-12s %s\n' "$name" "$result"
done

if [ "$failures" -gt 0 ]; then
  echo
  echo "$failures scenario(s) failed"
  exit 1
fi
