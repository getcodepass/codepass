# Evals

Regression tests for `plugins/codepass/skills/pr-review/SKILL.md`. Each scenario generates a
throwaway fixture repo in a temp dir (fixtures are generator scripts, never committed repos),
invokes `/codepass:pr-review` headlessly against **this checkout's** plugin (`--plugin-dir`, not
whatever version is installed), and greps the report for coarse invariants — dimension,
severity, secret masking, disposition. Never exact output: LLM output varies, invariants stay
stable.

## Cost — read first

**Every scenario is one real `claude -p` run and burns real tokens.** Run the full set on
demand and before a release/version bump — not in per-push CI. While iterating on one
scenario, run just that one. The `fleet` scenario costs more still: one run spawns
sub-agents, each of them a real model run.

## Run

```bash
bash tests/run-evals.sh             # all scenarios
bash tests/run-evals.sh secret      # one scenario
bash tests/run-evals.sh --help      # list scenarios
```

Prints a pass/fail table; exits non-zero on any failure. On a failed scenario the captured
report and stderr are dumped for inspection.

Requirements: an authenticated `claude` CLI. Local-mode scenarios need **no network** — the
tool allowlist permits only read-only git plus Read/Glob/Grep, and `base-trap`'s "origin" is
a local bare repo. The `fleet` scenario additionally permits sub-agent spawning (`Agent`).

Knobs (env vars):

| Var | Default | Meaning |
|-----|---------|---------|
| `EVAL_TIMEOUT_SECS` | `420` | wall clock per review (bounds hangs on interactive questions) |
| `EVAL_BUDGET_USD` | `2` | `--max-budget-usd` per review |
| `EVAL_MODEL` | unset | optional `--model` override |
| `EVAL_EXTRA_TOOLS` | unset | extra `--allowedTools` entries (the fleet scenario passes `Agent Task`) |

## Scenarios

| Name | Guards |
|------|--------|
| `secret` | hardcoded secret → Critical finding; the value itself is never echoed |
| `logic-bug` | guaranteed-crash bug → High-or-worse finding, REQUEST_CHANGES |
| `claude-md` | diff breaks the fixture's CLAUDE.md rule and a `.claude/rules/` rule → findings cite each convention file |
| `conventions-pinned` | the diff loosens CLAUDE.md *and* breaks the committed rule → judged against HEAD's copy, so the violation is still reported (the rule is arbitrary, so reading the working-tree copy finds nothing) |
| `clean` | benign diff → zero findings, APPROVE ("don't invent findings"), no fleet |
| `untracked` | defect only in an untracked file (in no diff) → still reviewed |
| `base-trap` | upstream is the same-named push target → base must resolve to main, not origin/feature |
| `ask-both` | dirty tree + unmerged commits → must ask which to review, no disposition |
| `fleet` | 30-file substantial diff, no flag → fleet self-activates (the report says so), one planted bug per cluster both found, REQUEST_CHANGES |

## Adding a scenario

Copy an existing executable script in `tests/scenarios/` (they are self-documenting), and
preserve its executable bit so the scenario can also be run directly:

1. Source `tests/lib.sh` — it gives you a trap-cleaned temp dir, `$FIXTURE` (empty repo dir),
   and helpers (`init_fixture`, `fixture_commit`, `run_review`, `assert_*`).
2. Build the repo state under `$FIXTURE` (extra pieces like a bare origin go in `$EVAL_TMP`).
3. `run_review` — captures the report in `$REPORT`, outside the fixture repo so the review
   never sees its own output as an untracked file.
4. Assert **coarse invariants** with `assert_matches`, `assert_not_matches`, `assert_finding`
   (findings-table rows per SKILL.md §9), `assert_absent` (checks stdout *and* stderr — use
   for planted secret values). Never assert exact wording.
5. End with `finish`.

The runner picks up any `tests/scenarios/<name>.sh` automatically. Planted "secrets" must be
obviously synthetic (`*_EVAL_FAKE_*`) — never real or realistic credentials.

## Gaps

- **PR mode is not covered.** Exercising it would need live GitHub PRs and (without
  `--dry-run`) would post reviews; these evals deliberately never touch the network. PR-mode
  changes still need the manual dry-run check from CONTRIBUTING. This leaves the riskiest
  surface — posting, `--post` selectors, the 422 retry, fork fetching, thread pagination and
  dedupe — guarded by nothing but that manual check. A `gh` shim on `PATH` serving canned
  fixture JSON would cover most of it without touching the network.
- **Convention pinning is covered only for local uncommitted work** (`conventions-pinned`).
  PR-mode pinning to the base branch, `.claude/rules/` pinning, and branch-vs-base pinning are
  not exercised.
- Invariants are necessary, not sufficient: a report can pass every grep and still be a poor
  review. Judging finding *content* would need an LLM judge (open question in issue #5).
- One run per scenario per invocation — a flaky pass/fail on a boundary case is possible;
  re-run the single scenario to confirm before acting on it.
