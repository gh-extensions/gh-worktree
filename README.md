# gh-worktree

> A GitHub CLI extension that spins up isolated git worktrees for AI-assisted work on pull requests, issues, and workflow runs

## Installation

```bash
gh extension install gh-extensions/gh-worktree
```

## Usage

```bash
gh worktree pr <number>    [-- <command>]
gh worktree issue <number> [-- <command>]
gh worktree run <id>       [-- <command>]
```

When no command is given after `--`, opens `$SHELL` in the worktree.
The worktree is removed when the command (or shell) exits.

## Examples

```bash
# Open a shell in a PR worktree
gh worktree pr 42

# Open gh-ai in a PR worktree
gh worktree pr 42 -- gh ai pr chat 42

# Open gh-ai in an issue worktree
gh worktree issue 55 -- gh ai issue chat 55

# Open gh-ai in a run worktree
gh worktree run 123 -- gh ai run chat 123
```

## How it works

- **pr** — fetches the PR head branch, creates a worktree tracking it
- **issue** — creates a new branch from the default branch
- **run** — creates a worktree pinned to the exact commit SHA that triggered the run

Dirty changes are auto-stashed before the worktree is removed. Unpushed commits are warned about but preserved in the branch reflog.

Worktrees are created under `.worktrees/<name>` in the repository root.

## Composing with gh-ai

`gh-worktree` owns the environment; `gh-ai` owns the context:

```
gh worktree pr 42 -- gh ai pr chat 42
  └── gh-worktree creates the worktree and runs the command inside it
        └── gh-ai detects it is inside a worktree and skips its own worktree setup
```
