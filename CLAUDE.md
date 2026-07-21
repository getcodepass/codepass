# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Claude Code plugin marketplace containing one plugin, **codepass** — a single-pass code review skill invoked as `/codepass:review`, covering both GitHub PRs and local (pre-commit) changes. There is no build system, test suite, or application code: the entire implementation is the prompt file `plugins/codepass/skills/review/SKILL.md`. Changes here are prompt engineering, not programming.

## Layout

- `.claude-plugin/marketplace.json` — marketplace manifest (`pluginRoot: ./plugins`)
- `plugins/codepass/.claude-plugin/plugin.json` — plugin manifest
- `plugins/codepass/skills/review/SKILL.md` — the whole implementation

## Commands

- Validate manifests and skill: `claude plugin validate .`
- Test a change: from a Claude Code session in any repo with an open PR, run `/codepass:review <PR-number-or-URL> --dry-run` (analyzes, posts nothing). Pass a full PR URL to exercise the cross-repo path. For local mode, run `/codepass:review` with no argument in a repo with uncommitted or unmerged work — it only prints, never posts.

## Versioning

The version lives in three places and must be bumped together: `metadata.version` and `plugins[0].version` in `.claude-plugin/marketplace.json`, and `version` in `plugins/codepass/.claude-plugin/plugin.json`.

After a version bump merges to `main`, create an annotated tag matching the new version and push it: `git tag -a vX.Y.Z <merge-sha> -m "codepass vX.Y.Z — <summary>" && git push origin vX.Y.Z`. Tags are the release checkpoints.

## SKILL.md design invariants

These constraints in the skill prompt are deliberate — don't relax them casually:

- **Single pass, no sub-agents, no local file modification.** The skill reviews exactly one PR or the local working copy, self-contained; fan-out is the caller's job.
- **Credential-agnostic.** Uses `gh` if authenticated, otherwise `curl` with `$GITHUB_TOKEN`/`$GH_TOKEN`. Never sets up or stores credentials.
- **Explicit repo resolution.** OWNER/REPO/PR_NUMBER resolved once from the argument; no later call may infer the repo from the working directory — that silently breaks cross-repo reviews.
- **Conventions read from the ref the diff is judged against** (PR → base branch, local uncommitted → HEAD, local branch → base), so a change can't loosen the rules it's graded by. Fork PRs fetch file contents from the head repo, not base.
- **Confidence ≥ 80 to report a finding.** Disposition (APPROVE / COMMENT / REQUEST_CHANGES) follows the thresholds in §7 of the skill.
- **Review payloads go on stdin, never temp files.** Reviews are pinned to the head SHA that was actually read.

## Style

- `SKILL.md` is a prompt file — write clear, unambiguous instructions.
- Keep bash examples copy-pasteable.
- Justify any change to severity/confidence thresholds.

Note: codepass reads the reviewed repo's `CLAUDE.md` as its convention source, so when a PR against *this* repo is reviewed with codepass, the rules in this file get cited verbatim.
