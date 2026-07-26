# Contributing to codepass

Thanks for your interest in contributing. This guide covers how to report issues, suggest features, and submit changes.

## Reporting Bugs

Open a [GitHub issue](https://github.com/getcodepass/codepass/issues/new?template=bug_report.yml) with:

- Steps to reproduce (PR number/URL, flags used)
- Expected vs actual behavior
- Claude Code version (`claude --version`)
- How you access GitHub (`gh` CLI — `gh --version` — or a token)
- OS

## Suggesting Features

Open a [feature request](https://github.com/getcodepass/codepass/issues/new?template=feature_request.yml). Include the use case and how you'd expect it to work.

## Development Setup

```bash
git clone https://github.com/getcodepass/codepass
cd codepass
```

### Validate the plugin

```bash
claude plugin validate .
```

### Test against a real PR

```bash
# In any repo with an open PR:
/codepass:pr-review <PR-number> --dry-run
```

### Test cross-repo review

```bash
/codepass:pr-review https://github.com/owner/repo/pull/123 --dry-run
```

### Test local mode

```bash
# In any repo with uncommitted changes or unmerged commits — prints only, never posts:
/codepass:pr-review
```

### Run the evals

`tests/` holds the regression suite for `SKILL.md`: fixture repos, a headless review each, and coarse invariant grading. **Every scenario is a real model run and costs real tokens**, so it does not run in CI — running it is part of submitting a change.

```bash
bash tests/run-evals.sh                    # all scenarios
bash tests/run-evals.sh conventions-pinned # just one, while iterating
bash tests/run-evals.sh --help             # list scenarios
```

Read [tests/README.md](tests/README.md) first for the cost notes, the env knobs (timeout, budget, model), and how to add a scenario. Local-mode scenarios need no network.

## Submitting Changes

1. Fork the repo and create a branch from `main`
2. Make your changes to `plugins/codepass/skills/pr-review/SKILL.md` or other files
3. Run `claude plugin validate .` to ensure the plugin is valid
4. Run the evals — the whole suite for a change to `SKILL.md`, or at minimum the scenarios covering what you touched. Add a scenario when you add behavior worth guarding
5. Test your changes against at least one real PR with `--dry-run` — and run local mode too if your change touches it. PR mode has no eval coverage, so this manual check is the only thing guarding it
6. Open a PR with a clear description of what changed and why

### What to include in your PR

- Description of the problem or feature
- How you tested it (which PRs, what scenarios)
- Any edge cases you considered

### Style

Style rules live in [CLAUDE.md](CLAUDE.md) — kept there so codepass itself cites them when
reviewing PRs to this repo.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
