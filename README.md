# gh-worktree

Spin up isolated git worktrees for pull requests, issues, and workflow runs —
without leaving the terminal.

Stop juggling branches. `gh worktree` checks out the right code, runs your
command inside a clean worktree, and tears everything down on exit.

## Prerequisites

- [Gum](https://github.com/charmbracelet/gum) — macOS: `brew install gum`
- [Bash](https://www.gnu.org/software/bash/) 4.4+ (`bash`) — macOS: `brew install bash`
- [GitHub CLI](https://cli.github.com/) (`gh`) — macOS: `brew install gh`
- [jq](https://jqlang.github.io/jq/) (`jq`) — macOS: `brew install jq`

## Installation

```bash
gh extension install gh-extensions/gh-worktree --pin v0.1.0  # recommended: pin to a stable release
gh extension install gh-extensions/gh-worktree                # installs from main (unstable)
```

## Usage

```bash
gh worktree pr <PR_NUMBER>       [--keep] [-- <command>]
gh worktree issue <ISSUE_NUMBER> [--keep] [-- <command>]
gh worktree run <RUN_ID>         [--keep] [-- <command>]
```

When no command is given after `--`, opens `$SHELL` in the worktree.
The worktree is removed when the command (or shell) exits. Pass `--keep` to
skip automatic cleanup and leave the worktree in place.

```bash
gh worktree --help               # show help
gh worktree --version            # print version
gh worktree pr --help            # pull request subcommand help
gh worktree issue --help         # issue subcommand help
gh worktree run --help           # workflow run subcommand help
```

### Pull Request

Fetches the PR head branch, creates a git worktree tracking it, and runs the
command inside.

```bash
gh worktree pr 42
gh worktree pr 42 -- nvim
gh worktree pr 42 -- gh ai pr chat 42
gh worktree pr 42 --keep
```

### Issue

Creates a new branch from the repository's default branch, creates a git
worktree, and runs the command inside.

```bash
gh worktree issue 55
gh worktree issue 55 -- nvim
gh worktree issue 55 -- gh ai issue chat 55
gh worktree issue 55 --keep
```

### Run

Fetches the workflow run's head branch and SHA, creates a git worktree pinned
to the exact commit that triggered the run, and runs the command inside.

```bash
gh worktree run 123
gh worktree run 123 -- nvim
gh worktree run 123 -- gh ai run chat 123
gh worktree run 123 --keep
```

## Worktrees & Branches

Each invocation creates a dedicated git worktree so the command runs in the
right code without touching your working tree or switching branches.

**Worktree location:** `<repo-root>/.github/worktrees/<name>`

The worktree name and branch strategy depend on the resource type:

| Command                | Worktree name | Branch                                                      |
| ---------------------- | ------------- | ----------------------------------------------------------- |
| `gh worktree pr 42`    | `pull-42`     | Checks out the PR head branch directly                      |
| `gh worktree issue 55` | `issue-55`    | Creates a new `issue-55` branch from `origin/<default>`     |
| `gh worktree run 123`  | `run-123`     | Creates a new `run-123` branch pinned to the run's head SHA |

**PR worktrees** check out the PR's head branch directly. If the branch already
exists locally it is fast-forwarded to the remote tip first (unless it has
diverged, in which case the local state is used as-is). Any commit made inside
can be pushed with a plain `git push` to update the PR — no extra flags needed.

**Issue worktrees** start a fresh branch from the repository's default branch.
Push the branch and open a PR when ready:

```bash
git push -u origin issue-55
gh pr create --head issue-55
```

**Run worktrees** start a fresh branch pinned to the run's exact `headSha` — the
commit that actually triggered the failure — regardless of how far the branch
has moved since. Push the branch and open a PR to land the fix:

```bash
git push -u origin run-123
gh pr create --head run-123
```

When the command exits, the worktree is automatically removed. If the worktree
has uncommitted changes, they are auto-stashed before removal so nothing is
lost. Recover them with `git stash list`. Unpushed commits remain in the branch
reflog.

Pass `--keep` to skip automatic cleanup. The worktree stays in place after the
process exits and must be removed manually:

```bash
git worktree remove .github/worktrees/pull-42
```

## Configuration

Override the worktree base directory via environment variable or `gh config`.

| Key                | Default             | Description                                   |
| ------------------ | ------------------- | --------------------------------------------- |
| `GH_WORKTREE_DIR`  | —                   | Env var override; highest priority            |
| `worktree.dir`     | `.github/worktrees` | `gh config` key; used when env var is not set |

```bash
# Set a custom worktree directory
gh config set worktree.dir /tmp/worktrees

# Or use an environment variable
GH_WORKTREE_DIR=/tmp/worktrees gh worktree pr 42
```

> **Note:** `gh config set` will print a warning for keys it doesn't
> recognize (e.g. `'worktree.dir' is not a known configuration key`).
> This is expected — the values are still saved and used by the extension.

Relative paths are resolved against the repository root. Absolute paths are
used as-is.

## Composing with gh-ai

[gh-ai](https://github.com/gh-extensions/gh-ai) is an AI-powered GitHub CLI
extension. Use `gh-worktree` to set up the environment and `gh-ai` to provide
context:

```bash
gh worktree pr 42 -- gh ai pr chat 42
gh worktree issue 55 -- gh ai issue chat 55
gh worktree run 123 -- gh ai run chat 123
```

`gh-worktree` owns the environment; `gh-ai` owns the context:

```text
gh worktree pr 42 -- gh ai pr chat 42
  └── gh-worktree creates the worktree and runs the command inside it
        └── gh-ai receives the PR context and runs inside the worktree
```

## See Also

- [gh-ai](https://github.com/gh-extensions/gh-ai) — AI-powered copilot for the GitHub CLI
- [gh-fzf](https://github.com/gh-extensions/gh-fzf) — Fuzzy finder for GitHub CLI

## License

[MIT](LICENSE) — Copyright (c) 2025 gh-extensions

<!-- markdownlint-disable-file MD013 MD036 -->
