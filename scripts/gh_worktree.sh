#!/usr/bin/env bash

set -euo pipefail

# Resolve the base directory for worktrees relative to the repo root.
#
# Resolution order:
#   1. GH_WORKTREE_DIR env var
#   2. gh config get worktree.dir
#   3. Default: .github/worktrees
#
# Usage: base=$(_worktree_base_dir <cwd>)
_worktree_base_dir() {
	local cwd="$1"
	local dir

	if [[ -n "${GH_WORKTREE_DIR:-}" ]]; then
		dir="$GH_WORKTREE_DIR"
	else
		dir=$(gh config get worktree.dir 2>/dev/null || true)
		dir="${dir:-.github/worktrees}"
	fi

	# Resolve relative paths against the repo root
	if [[ "$dir" != /* ]]; then
		dir="${cwd}/${dir}"
	fi

	printf '%s' "$dir"
}

# Check if a worktree has uncommitted changes (untracked, modified, staged)
#
# Returns 0 if dirty, 1 if clean.
#
# Usage: _worktree_is_dirty "/path/to/worktree"
_worktree_is_dirty() {
	local wt="$1"
	[[ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]]
}

# Check if a worktree has commits not pushed to any remote
#
# Returns 0 if there are unpushed commits, 1 otherwise.
# Uses --not --remotes so no upstream tracking branch is required.
#
# Usage: _worktree_has_unpushed "/path/to/worktree"
_worktree_has_unpushed() {
	local wt="$1"
	local ahead
	ahead=$(git -C "$wt" rev-list --count HEAD --not --remotes 2>/dev/null || echo "0")
	[[ "$ahead" -gt 0 ]]
}

# Create a git worktree
#
# Usage: _worktree_create <cwd> <name> <remote_ref> [<head_sha>] [<branch>]
#
#   cwd         — repo root
#   name        — worktree name; used as local branch name when branch is empty
#   remote_ref  — remote branch to fetch (e.g. "feature/my-branch")
#   head_sha    — optional SHA to pin to (run sessions); empty uses remote tip
#   branch      — optional local branch name; empty means use name (issue/run)
#                 when set and matching remote_ref, auto-tracking is enabled (PR)
#
# Stdout: worktree path
# Stderr: git output
_worktree_create() {
	local cwd="$1"
	local name="$2"
	local remote_ref="$3"
	local head_sha="${4:-}"
	local branch="${5:-}"

	local base_dir
	base_dir=$(_worktree_base_dir "$cwd")
	local worktree_path="${base_dir}/${name}"
	mkdir -p "$base_dir"

	local wt_list
	wt_list=$(git -C "$cwd" worktree list --porcelain)

	# Reuse existing worktree instead of failing
	if grep -qxF "worktree ${worktree_path}" <<<"$wt_list"; then
		printf '%s\n' "$worktree_path"
		return 0
	fi

	local checkout_branch="${branch:-$name}"

	# Refuse if the branch is already checked out elsewhere
	if grep -qxF "branch refs/heads/${checkout_branch}" <<<"$wt_list"; then
		echo "_worktree_create: branch '${checkout_branch}' is already checked out in another worktree" >&2
		return 1
	fi

	if git -C "$cwd" show-ref --verify --quiet "refs/heads/${checkout_branch}"; then
		# Fast-forward the local branch to the remote tip before checking out.
		# If diverged (local commits ahead), the fetch refuses and the worktree
		# opens at the local state instead.
		git -C "$cwd" fetch origin "${checkout_branch}:${checkout_branch}" >&2 || true
		git -C "$cwd" worktree add "$worktree_path" "${checkout_branch}" >&2
	else
		git -C "$cwd" fetch origin "$remote_ref" >&2 || true

		# Pin to SHA when provided (run sessions), otherwise use remote branch tip.
		local git_ref="${head_sha:-origin/${remote_ref}}"

		# Enable auto-tracking only when checking out the PR head branch so that
		# `git push` updates the PR without extra flags. Issue/run sessions use
		# --no-track to avoid wiring a local branch to the wrong remote ref.
		local track_flag=""
		[[ "$checkout_branch" != "$branch" ]] && track_flag="--no-track"
		git -C "$cwd" worktree add ${track_flag:+"$track_flag"} -b "${checkout_branch}" "$worktree_path" "$git_ref" >&2
	fi

	printf '%s\n' "$worktree_path"
}

# Remove a git worktree, auto-stashing dirty changes beforehand
#
# Silently succeeds if the worktree path does not exist.
# Warns about unpushed commits (they survive in the branch reflog).
#
# Usage: _worktree_remove <worktree_path>
_worktree_remove() {
	local worktree_path="$1"

	if [[ ! -d "$worktree_path" ]]; then
		return 0
	fi

	if _worktree_is_dirty "$worktree_path"; then
		local wt_name
		wt_name=$(basename "$worktree_path")
		git -C "$worktree_path" add -A 2>/dev/null || true
		if git -C "$worktree_path" stash push -m "gh-worktree: auto-stash '${wt_name}'" 2>/dev/null; then
			echo "Auto-stashed uncommitted changes from '${wt_name}' — recover with: git stash list" >&2
		fi
	fi

	if _worktree_has_unpushed "$worktree_path"; then
		local branch
		branch=$(git -C "$worktree_path" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
		echo "Warning: branch '${branch}' has unpushed commits — they remain in the reflog" >&2
	fi

	git -C "$worktree_path" worktree remove -f "$worktree_path" 2>/dev/null || true
}

# Resolve the git repository root directory
#
# Writes the result into the nameref; returns 1 and logs an error on failure.
#
# Usage: _git_repo_path git_dir_ref
_git_repo_path() {
	local -n _git_dir_ref="$1"
	_git_dir_ref=$(git rev-parse --show-toplevel 2>/dev/null || true)
	if [[ -z "$_git_dir_ref" ]]; then
		gum log --level error "Not inside a git repository"
		return 1
	fi
}

# Split arguments on the first -- separator
#
# Everything before -- goes into args_ref; everything after into cmd_ref.
#
# Usage: _split_args args_ref cmd_ref "$@"
_split_args() {
	local -n _sa_args="$1"
	local -n _sa_cmd="$2"
	shift 2

	_sa_args=()
	_sa_cmd=()

	while [[ $# -gt 0 ]]; do
		if [[ "$1" == "--" ]]; then
			shift
			_sa_cmd=("$@")
			return 0
		fi
		_sa_args+=("$1")
		shift
	done
}

# Run a command (or $SHELL) inside the worktree, removing the worktree on exit.
#
# Usage: _run_in_worktree <worktree_path> [cmd...]
_run_in_worktree() {
	local worktree_path="$1"
	shift
	local cmd=("$@")

	# shellcheck disable=SC2064
	trap "_worktree_remove $(printf '%q' "$worktree_path")" EXIT

	cd "$worktree_path"

	if [[ ${#cmd[@]} -gt 0 ]]; then
		"${cmd[@]}"
	else
		"$SHELL"
	fi
}

# When executed directly (not sourced), dispatch to the named function.
#
# Usage: bash gh_worktree.sh create <args...>
#        bash gh_worktree.sh remove <worktree_path>
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	cmd="${1:-}"
	shift
	case "$cmd" in
	create) _worktree_create "$@" ;;
	remove) _worktree_remove "$@" ;;
	*) echo "gh_worktree.sh: unknown command '${cmd}'" >&2; exit 1 ;;
	esac
fi
