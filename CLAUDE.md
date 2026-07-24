# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Claude Code plugin marketplace containing one plugin, **codepass** — a code review skill (one pass for small diffs; automatic fleet fan-out when coverage demands it) invoked as `/codepass:pr-review`, covering both GitHub PRs and local (pre-commit) changes. There is no build system or application code: the entire implementation is the prompt file `plugins/codepass/skills/pr-review/SKILL.md`. Changes here are prompt engineering, not programming — regression-tested by the eval suite in `tests/` (see `tests/README.md`; each scenario costs a real model run).

## Layout

- `.claude-plugin/marketplace.json` — marketplace manifest (`pluginRoot: ./plugins`)
- `plugins/codepass/.claude-plugin/plugin.json` — plugin manifest
- `plugins/codepass/skills/pr-review/SKILL.md` — the whole implementation
- `tests/` — eval harness: fixture scenarios + invariant grading (`bash tests/run-evals.sh [scenario]`)

## Commands

- Validate manifests and skill: `claude plugin validate .`
- Test a change: from a Claude Code session in any repo with an open PR, run `/codepass:pr-review <PR-number-or-URL> --dry-run` (analyzes, posts nothing). Pass a full PR URL to exercise the cross-repo path. For local mode, run `/codepass:pr-review` with no argument in a repo with uncommitted or unmerged work — it only prints, never posts.

## Versioning

The version lives in three places and must be bumped together: `metadata.version` and `plugins[0].version` in `.claude-plugin/marketplace.json`, and `version` in `plugins/codepass/.claude-plugin/plugin.json`.

After a version bump merges to `main`, create an annotated tag matching the new version and push it: `git tag -a vX.Y.Z <merge-sha> -m "codepass vX.Y.Z — <summary>" && git push origin vX.Y.Z`. Tags are the release checkpoints.

## SKILL.md design invariants

These constraints in the skill prompt are deliberate — don't relax them casually:

- **Coverage decides fleet; adjudication stays single-context.** The skill reviews exactly one PR or the local working copy, self-contained; fan-out across PRs is the caller's job. Small diffs get exactly one pass, zero sub-agents. Past 20 reviewable files (a firm rule — self-assessed single-pass coverage is not trusted), or when a smaller diff is too large to read carefully, the *reading* fans out to read-only sub-agents — no file modification, no posting, no nesting — while falsification, dedupe, scoring, and disposition stay in the main context; on a close call it fleets (quality over cost). `--fleet` forces, `--no-fleet` forbids. It never stops to ask about size (that hangs headless runs). No local file modification, ever, in either mode.
- **Credential-agnostic.** Uses `gh` if authenticated, otherwise `curl` with `$GITHUB_TOKEN`/`$GH_TOKEN`. Never sets up or stores credentials.
- **Explicit repo resolution.** OWNER/REPO/PR_NUMBER resolved once from the argument; no later call may infer the repo from the working directory — that silently breaks cross-repo reviews.
- **Conventions read from the ref the diff is judged against** (PR → base branch, local uncommitted → HEAD, local branch → base), so a change can't loosen the rules it's graded by. Fork PRs fetch file contents from the head repo, not base.
- **Confidence ≥ 80 to report a finding.** Disposition (APPROVE / COMMENT / REQUEST_CHANGES) follows the thresholds in §7 of the skill.
- **Review payloads go on stdin, never temp files.** Reviews are pinned to the head SHA that was actually read.

## Style

- `SKILL.md` is a prompt file — write clear, unambiguous instructions.
- Keep bash examples copy-pasteable.
- Justify any change to severity/confidence thresholds.

Note: codepass reads the reviewed repo's `CLAUDE.md` and `.claude/rules/` as its convention sources, so when a PR against *this* repo is reviewed with codepass, the rules in this file get cited verbatim.
