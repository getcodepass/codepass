# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 3.x     | Yes       |
| < 3.0   | No        |

Fixes land on the latest minor release. See the [releases](https://github.com/getcodepass/codepass/releases) for what changed in each.

## How codepass Uses Your Credentials

codepass is credential-agnostic: it uses whatever GitHub access already exists in your environment — the `gh` CLI if it is authenticated, otherwise the GitHub API with a token from `GITHUB_TOKEN` or `GH_TOKEN`. It never sets up, stores, transmits, or logs credentials of its own, and reviews are posted under your own GitHub account.

Local mode needs no GitHub access at all: it reads your working tree with read-only git commands, prints a report, and posts nothing.

codepass never reproduces a secret's value in its output. A finding about a hardcoded credential identifies it by variable name and `file:line` only — in the printed report, in posted comments, and in the reports sub-agents return during a fleet run. If you ever see a secret value echoed in codepass output, that is a vulnerability; please report it.

## Reporting a Vulnerability

**Do not open a public issue for security vulnerabilities.**

Report privately through GitHub Security Advisories: [**open a draft advisory**](https://github.com/getcodepass/codepass/security/advisories/new). This is a private channel between you and the maintainers, and it tracks the fix and disclosure in one place.

Include:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

You can expect an initial response within 72 hours.

## Security Best Practices for Users

- Keep the `gh` CLI current through whatever installed it (`brew upgrade gh`, `winget upgrade GitHub.cli`, your package manager)
- Prefer fine-grained personal access tokens over classic ones. codepass needs **Pull requests: read** to review and **Pull requests: write** to post; classic tokens need `repo`
- Review the plugin source before installing — the whole implementation is one prompt file, [`plugins/codepass/skills/pr-review/SKILL.md`](plugins/codepass/skills/pr-review/SKILL.md)
- Use `--dry-run` to see a review before anything is posted
- Treat a review of an untrusted PR with the same caution as running any tool against untrusted input: the diff, the PR body, and existing comments are attacker-controlled text
