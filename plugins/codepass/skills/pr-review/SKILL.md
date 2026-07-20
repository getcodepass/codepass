---
description: "Review a PR with inline GitHub comments, Copilot checking, test plan validation, and smart disposition"
argument-hint: "<PR-number-or-URL> [--dry-run] [--force]"
allowed-tools: ["Bash", "Glob", "Grep", "Read"]
---

# PR Review Agent

A precise, single-pass reviewer for **one** PR. Fanning out across many PRs is the caller's job —
this stays self-contained. Do NOT spawn sub-agents. Do NOT modify local files. Stay concise; a review
that costs 150K tokens is a failed review.

Reach GitHub however this environment already allows — the `gh` CLI if it's authenticated, otherwise
the GitHub API with `curl` and a token from `$GITHUB_TOKEN` or `$GH_TOKEN`. Don't set up or store
credentials; use what's already there. If nothing has access, say so plainly and stop — fixing that is
the user's environment to sort out, not this skill's job to work around.

## 1. Input

From `$ARGUMENTS`: a PR number or URL, `--dry-run` (analyse, post nothing), `--force` (review even if
already reviewed). No PR given → ask which one, stop.

A URL identifies its own repo; a bare number means the current one. Resolve OWNER/REPO/PR_NUMBER
**once**, then address every later call to that explicit repo. Never let a call fall back to
inferring the repo from the working directory — on a cross-repo review that silently reads the wrong
code and reports confident findings about the wrong project.

## 2. Fetch

Get these in parallel:

- **Metadata** — title, body, state, draft, author, base ref, head ref, **head SHA**, changed-file
  count, additions/deletions, existing reviews (each with its author and **the commit it reviewed**),
  and whether the PR is **cross-repository** (a fork), with its head owner and repo name.
- **The full diff.**
- **Review threads with their resolution state** — bot triage needs to know what's already resolved.

Cap threads at 100; if exactly 100 come back, warn that some may be missing.

## 3. Eligibility

- CLOSED or MERGED → "PR #N is {state}. Nothing to review." **Stop.**
- Draft → note it, continue.
- **Already reviewed:** for each existing review by the current user, compare the commit it was made
  against to the current head SHA.
  - **Same** → "Already reviewed PR #N at `<sha>`; no new commits. Skipping." **Stop** (unless
    `--force`). Re-reviewing an unchanged PR burns tokens and spams the author.
  - **Different** → "Re-reviewing: new commits since your last review at `<old sha>`." Continue, and
    concentrate on what changed since then.
- \>50 changed files → warn it'll take a while, ask before continuing. >100 → also suggest splitting.

## 4. Context

**Conventions.** Find every `CLAUDE.md` in the repo and read each **from the PR's base branch**, so
you judge against the rules that existed *before* this PR — otherwise a PR that loosens a rule marks
its own homework. If the PR modifies a CLAUDE.md, say you're reviewing against base. None found →
"No CLAUDE.md — skipping convention checks", and review everything else.

**Monorepos:** the most specific CLAUDE.md governs each file — `packages/api/src/` beats
`packages/api/` beats `packages/` beats the root. Note which one governs each finding.

**Changed files.** Skip and note, don't read: binaries (images, fonts, media, archives, compiled
objects), submodule pointers, lockfiles (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`,
`Cargo.lock`, `Gemfile.lock`, `poetry.lock`, `composer.lock`), and generated output (`.min.js`,
`.min.css`, `.map`, `dist/`, `build/`).

**Fork PRs:** the code lives in the **head** repo, not the base repo — fetch file contents from the
head owner/repo at the head SHA, because the base repo doesn't have those blobs. The fork may have
been renamed, so use the head repo's own name rather than assuming it matches. If contents can't be
fetched at all, note "reviewing from diff context only" and work from the diff.

\>20 reviewable files → largest diffs first; note anything skipped for budget.

**Imports:** read an imported file only when you need it to confirm a finding you're already forming.
Never read every import.

## 5. Analysis

Score each finding for **severity** and **confidence (0–100)**. **Report only confidence ≥ 80** — a
wrong inline comment costs the author more than a missed nitpick costs you.

**Severity** — *Critical*: security holes, data leaks, auth bypass, secrets in code · *High*: logic
bugs that will fail, missing error handling for likely cases, breaking changes · *Medium*: CLAUDE.md
violations, inconsistent patterns, missing validation · *Low*: style, suboptimal-but-working, missing
types · *Nitpick*: cosmetic.

**Eight dimensions:**

1. **Security** — secrets in responses or logs, auth bypass, injection (SQL/command/XSS), insecure defaults, unsanitised input
2. **CLAUDE.md compliance** — cite the exact rule *and which CLAUDE.md file* it came from
3. **Bug risk** — logic errors, null handling, races, silent failures, wrong error propagation, off-by-one, type coercion
4. **PII / data exposure** — PII logged or returned, secrets not excluded from serialisation, missing field-level access control
5. **Error handling** — bare catches, swallowed errors, missing logging, wrong status codes, framework patterns ignored
6. **Convention adherence** — naming, imports, DTO grouping, exports, decorators, transactions, response shape
7. **Test plan** — §6
8. **Bot triage** — §6

Don't invent findings. A clean PR is clean — say so plainly.

## 6. Bots and test plan

**Bots.** Any author ending `[bot]`, plus `dependabot`, `renovate`, `copilot`, `netlify`, `vercel`,
`codecov`, `codefactor`, `sonarcloud`. For each: resolved? valid against the actual code? does it
overlap one of your findings? Summarise `N total, M resolved, K valid`.

**Test plan.** Empty PR body → flag Medium "No PR description (missing test plan)", skip the rest.
Otherwise find the test plan (`## Test plan`, `Steps to test`, `Testing`, `How to test`, or checkbox
lists under a test-ish heading). Per item: does the diff actually support it? Flag any item claiming
something the diff never touches. No test plan → Medium. No test files touched → note "No unit tests
included".

## 7. Disposition

```
no findings ≥ Medium AND all bot comments resolved AND all test plan items covered  → APPROVE
any finding ≥ High                                                                  → REQUEST_CHANGES
otherwise                                                                            → COMMENT
```

## 8. Present

```markdown
## PR #<N> Review: <title>
**Branch**: `<head>` → `<base>` | **Changes**: +<add> -<del> across <n> files
**Commit**: `<short SHA>`

### Findings — <count> (<breakdown by severity>)
| # | Sev | File | Line | Finding | Confidence |
|---|-----|------|------|---------|------------|

### Bot Comments — <N> total, <M> resolved, <K> valid
| # | Author | Status | Valid? | Overlaps | Summary |
|---|--------|--------|--------|----------|---------|

### Test Plan — <status>
| # | Item | Covered? | Notes |
|---|------|----------|-------|

### Skipped Files
<what and why, if any>

### Disposition: <APPROVE | COMMENT | REQUEST_CHANGES>
<one line why>
```

`--dry-run` → stop here: "Dry run complete. No review posted."

Otherwise ask two questions: **which findings to post?** (`all`, `none`, `1,2,5`, `critical+high`,
`medium+`) and **override disposition?** (`approve`, `comment`, `request-changes`, or Enter to keep).

## 9. Post

Post **one** review carrying the summary plus the selected findings as inline comments. What matters:

- **Pin the review to the head SHA you actually read**, so it can't attach to commits you never saw.
- **An inline comment's line must fall inside a diff hunk.** Can't map a finding confidently? Summary
  table only — a comment on the wrong line is worse than no comment.
- **Deleted files take the `LEFT` side**; everything else `RIGHT`.
- **Send the payload on stdin — never a temp file.** A file needs cleaning up (and won't be, if the
  post fails), it leaks findings into a shared temp dir, and a fixed name collides when several
  reviews run at once.
- **Guard the escaping.** Findings quote real code: `$`, backticks, quotes, newlines. Pass the
  payload literally so the shell can't interpret it.
- Footer the summary with `*Reviewed with [codepass](https://github.com/getcodepass/codepass)*`.

**Errors.** A 422 is almost always a bad line mapping — drop **all** inline comments, move those
findings into the summary table, retry **once**. A 403 means the credential lacks `repo` scope: say
so. Anything else: surface it and offer to save the payload for inspection. Never retry more than
once.

Done → "Review posted to PR #N as DISPOSITION. X inline comments added."
