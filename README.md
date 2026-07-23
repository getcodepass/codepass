# codepass

Single-pass code review plugin for Claude Code — review a GitHub PR, or your local changes before you commit. Posts inline PR comments, cites your CLAUDE.md conventions, validates test plans, and auto-determines review disposition.

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- For PR mode: GitHub API access from the command line — either the [`gh` CLI](https://cli.github.com/) authenticated (`gh auth login`), or a token in `GITHUB_TOKEN` / `GH_TOKEN`. codepass uses whatever is already set up; it does not manage credentials. **Local mode needs no GitHub access at all.**

## Installation

```bash
claude plugin marketplace add getcodepass/codepass
claude plugin install codepass
```

## Usage

Open Claude Code inside any git repository:

```bash
# Start Claude Code in your repo
claude
```

Then use the slash command inside Claude Code:

```bash
# Review your local changes before you commit — uncommitted work and/or
# commits not yet merged to your base branch. Prints findings, posts nothing.
/codepass:review

# Review a PR by number
/codepass:review 219

# Review a PR by URL
/codepass:review https://github.com/org/repo/pull/219

# Analyze a PR without posting (dry run)
/codepass:review 219 --dry-run

# Re-review even if you already reviewed the current commit
/codepass:review 219 --force
```

## Features

### Two Modes, One Reviewer
- **PR mode** — pass a PR number or URL: fetches the PR, posts an inline review
- **Local mode** — pass nothing: reviews uncommitted work and/or commits not yet merged to your base branch, prints the report, never posts

### 7-Dimension Analysis
1. **Security** — Token/secret exposure, auth bypass, injection vectors
2. **CLAUDE.md Compliance** — Convention violations with specific rule citations
3. **Bug Risk** — Logic errors, null handling, race conditions, silent failures
4. **PII / Data Exposure** — Logged PII, sensitive fields in responses
5. **Error Handling** — Framework-specific exception patterns, swallowed errors
6. **Convention Adherence** — Naming, imports, DTOs, module rules
7. **Test Plan Validation** — PR description test plan vs actual implementation

### No Repeated Feedback
In PR mode, existing review comments — from humans and bots alike — are checked before posting: anything already raised isn't repeated, and resolved threads stay settled.

### Smart Disposition
- **APPROVE** — No medium+ findings, all existing review threads resolved, test plan covered
- **REQUEST_CHANGES** — Any high/critical findings
- **COMMENT** — Medium findings or unresolved review threads

In local mode the same thresholds read as a readiness verdict — APPROVE means "ready to commit / open a PR".

### Selective Posting
After analysis, choose which findings to post:
- `all` — Post everything
- `1,2,5` — Post specific findings by number
- `critical+high` — Post by severity threshold
- `none` — Skip posting

## How It Compares

| Tool | Cost | Context | Convention Awareness | Structured Analysis | Disposition Logic | Status |
|------|------|---------|---------------------|--------------------|--------------------|--------|
| **codepass** | **Free** | **Changed files + diff + metadata (single pass)** | **Yes (CLAUDE.md)** | **7 dimensions** | **Yes** | **Active** |
| [ai-pr-reviewer](https://github.com/coderabbitai/ai-pr-reviewer) | Free (BYOK) | Diff chunks (incremental) | No | None | No | Unmaintained |
| [ai-codereviewer](https://github.com/villesau/ai-codereviewer) | Free (BYOK) | Diff chunks (one-shot) | No | None | No | Unmaintained |
| [CodeRabbit](https://coderabbit.ai) | $12-24/dev/mo | Full repo clone + code graph + semantic index | Config files | Multi-linter (40+) | Yes | Active |
| [Copilot PR Review](https://docs.github.com/en/copilot) | $10-39/dev/mo | Diff + agentic file retrieval | `.github/copilot-instructions.md` | Risk scoring | No | Active |
| [Qodo Merge](https://github.com/qodo-ai/pr-agent) | Free (OSS) / $30-45/dev/mo | Diff + token budgeting + chunking | Config files (paid) | Single LLM call | No | Active |

**What makes codepass different:**
- **Convention-first** — reads your `CLAUDE.md` from the ref the diff is judged against — the PR's base branch, or `HEAD` locally — and cites the exact rule violated. Pinning conventions to that ref means a change can't loosen the rules it's graded by: it never marks its own homework. No other tool does this natively.
- **Reviews before the PR exists** — the same reviewer runs on your uncommitted work locally, so problems get caught before anything is pushed.
- **Findings must survive falsification** — before reporting, the reviewer tries to disprove each candidate against the actual code; what survives only by plausibility gets dropped, not posted.
- **Single-pass, zero agents** — one context window, no agent spawning.
- **You control what gets posted** — selective posting by finding number or severity threshold. No auto-spam.

## How It Works

**PR mode** (a PR number or URL was given):

1. Confirms it can reach the GitHub API with your existing access
2. Parses PR number or URL, resolves the target repo explicitly for all API calls
3. Fetches PR metadata, diff, and review threads (3 parallel API calls)
4. Warns if PR has 50+ changed files
5. Reads CLAUDE.md conventions from the **base branch** (not the PR head)
6. Fetches changed files — uses GitHub API for fork PRs, skips binaries/lockfiles
7. Analyzes across 7 dimensions in a single pass
8. Presents structured findings with severity and confidence scores
9. Asks which findings to post and whether to override disposition
10. Posts review with inline comments pinned to the specific commit SHA

**Local mode** (no argument):

1. Detects what there is to review with read-only git commands: uncommitted work (including untracked files), commits not yet merged to your base branch, or both — and asks when it's ambiguous
2. Resolves the base as your merge target (upstream if it's a different branch, else the default branch), never the push target
3. Reads CLAUDE.md conventions from the ref the diff is judged against (`HEAD` for uncommitted work, the base for branch review)
4. Analyzes the same 7 dimensions and prints the same structured report
5. Stops there — nothing is posted, nothing leaves your machine

## Configuration

No configuration needed — but works best when your repo has a `CLAUDE.md` with project conventions. Without one, codepass skips convention checks and still reviews the other six dimensions.

The plugin:
- Detects repo from your current directory or from the provided URL
- Uses whatever GitHub access is already configured (`gh` CLI, or a token in `GITHUB_TOKEN` / `GH_TOKEN`)
- Reads `CLAUDE.md` files from the base branch of whatever repo the PR targets
- Posts reviews under your own GitHub account
- Pins reviews to the PR's head commit SHA to avoid stale line comments

## Limitations

- **Review threads**: Fetches up to 100 threads with 20 comments each
- **Binary/lock files**: Automatically skipped
- **Large PRs**: Warns at 50+ files. Files prioritized by diff size.
- **Fork PRs**: Requires the fork repo to be readable with your GitHub access
- **Duplicate reviews**: Running twice creates a second review (GitHub doesn't support editing reviews)
- **Local mode**: report only — never posts, and never modifies your working tree (read-only git throughout)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

See [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
