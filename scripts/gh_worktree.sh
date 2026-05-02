#!/usr/bin/env bash

[ -z "${DEBUG:-}" ] || set -x

set -euo pipefail

# Resolve the base directory for worktrees relative to the repo root.
#
# Resolution order:
#   1. GH_WORKTREE_PATH env var
#   2. gh config get worktree.path
#   3. Default: .github/worktrees
#
# Stdout: base directory path
# Usage: base=$(_gh_worktree_base_dir <cwd>)
_gh_worktree_base_dir() {
	local cwd="$1"
	local dir

	if [[ -n "${GH_WORKTREE_PATH:-}" ]]; then
		dir="$GH_WORKTREE_PATH"
	else
		dir=$(gh config get worktree.path 2>/dev/null || true)
		dir="${dir:-.github/worktrees}"
	fi

	# Resolve relative paths against the repo root
	if [[ "$dir" != /* ]]; then
		dir="${cwd}/${dir}"
	fi

	printf '%s' "$dir"
}

# Generate a deterministic UUIDv5 from a name string.
#
# Uses the OID namespace (2.16.840) and openssl for SHA-1 hashing.
# Stdout: UUID string (e.g. "3d813cbb-47fb-5b9b-9cf2-e60d07e08e7f")
#
# Usage: _uuidv5 <name>
_uuidv5() {
	local name="$1"
	# OID namespace: 6ba7b812-9dad-11d1-80b4-00c04fd430c8
	local hash
	hash=$(
		{
			printf '\x6b\xa7\xb8\x12\x9d\xad\x11\xd1\x80\xb4\x00\xc0\x4f\xd4\x30\xc8'
			printf '%s' "$name"
		} | openssl dgst -sha1 | awk '{print $NF}'
	)
	local b8
	b8=$(printf '%02x' $(((16#${hash:16:2} & 0x3f) | 0x80)))
	printf '%s-%s-%s%s-%s%s-%s\n' \
		"${hash:0:8}" "${hash:8:4}" \
		"5" "${hash:13:3}" \
		"$b8" "${hash:18:2}" \
		"${hash:20:12}"
}

# Check if a worktree has uncommitted changes (untracked, modified, staged)
#
# Returns 0 if dirty, 1 if clean.
#
# Usage: _gh_worktree_is_dirty "/path/to/worktree"
_gh_worktree_is_dirty() {
	local wt="$1"
	[[ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]]
}

# Check if a worktree has commits not pushed to any remote
#
# Returns 0 if there are unpushed commits, 1 otherwise.
# Uses --not --remotes so no upstream tracking branch is required.
#
# Usage: _gh_worktree_has_unpushed "/path/to/worktree"
_gh_worktree_has_unpushed() {
	local wt="$1"
	local ahead
	ahead=$(git -C "$wt" rev-list --count HEAD --not --remotes 2>/dev/null || echo "0")
	[[ "$ahead" -gt 0 ]]
}

# Create a git worktree
#
# Usage: _gh_worktree_create <cwd> <name> <remote_ref> [<head_sha>] [<branch>]
#
#   cwd         — repo root
#   name        — worktree name; used as local branch name when branch is empty
#   remote_ref  — remote branch to fetch (e.g. "feature/my-branch")
#   head_sha    — optional SHA to pin to (run sessions); empty uses remote tip
#   branch      — optional local branch name; empty means use name (issue/run)
#                 when set, auto-tracking is enabled so `git push` updates the PR (PR sessions)
#
# Stdout: worktree path
# Stderr: git output
_gh_worktree_create() {
	local cwd="$1"
	local name="$2"
	local remote_ref="$3"
	local head_sha="${4:-}"
	local branch="${5:-}"

	local base_dir
	base_dir=$(_gh_worktree_base_dir "$cwd")
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
		gum log --level error "branch '${checkout_branch}' is already checked out in another worktree"
		return 1
	fi

	local git_err=""
	if git -C "$cwd" show-ref --verify --quiet "refs/heads/${checkout_branch}"; then
		# Fast-forward the local branch to the remote tip before checking out.
		# If diverged (local commits ahead), the fetch refuses and the worktree
		# opens at the local state instead.
		git -C "$cwd" fetch origin "${checkout_branch}:${checkout_branch}" 2>/dev/null ||
			gum log --level warn "Could not update '${checkout_branch}' from remote — opening at local state"
		if ! git_err=$(git -C "$cwd" worktree add "$worktree_path" "${checkout_branch}" 2>&1); then
			gum log --level error "$git_err"
			return 1
		fi
	else
		git -C "$cwd" fetch origin "$remote_ref" 2>/dev/null || true

		# Pin to SHA when provided (run sessions), otherwise use remote branch tip.
		local git_ref="${head_sha:-origin/${remote_ref}}"

		# Enable auto-tracking only when checking out the PR head branch so that
		# `git push` updates the PR without extra flags. Issue/run sessions use
		# --no-track to avoid wiring a local branch to the wrong remote ref.
		local track_flag=""
		[[ "$checkout_branch" != "$branch" ]] && track_flag="--no-track"
		if ! git_err=$(git -C "$cwd" worktree add ${track_flag:+"$track_flag"} -b "${checkout_branch}" "$worktree_path" "$git_ref" 2>&1); then
			gum log --level error "$git_err"
			return 1
		fi
	fi

	printf '%s\n' "$worktree_path"
}

# Remove a git worktree, auto-stashing dirty changes beforehand
#
# Dirty changes — including untracked files — are staged with `git add -A`
# then stashed, so they survive worktree removal and can be recovered via
# `git stash list` in the main repository.
# Silently succeeds if the worktree path does not exist.
# Warns about unpushed commits (they survive in the branch reflog).
#
# Usage: _gh_worktree_remove <worktree_path>
_gh_worktree_remove() {
	local worktree_path="$1"

	if [[ ! -d "$worktree_path" ]]; then
		return 0
	fi

	if _gh_worktree_is_dirty "$worktree_path"; then
		local worktree_name
		worktree_name=$(basename "$worktree_path")

		git -C "$worktree_path" add -A 2>/dev/null || true
		if git -C "$worktree_path" stash push -m "gh-worktree: auto-stash worktree '${worktree_name}'" >/dev/null 2>&1; then
			gum log --level info "Auto-stashed uncommitted changes from worktree '${worktree_name}' — recover with: git stash list"
		fi
	fi

	if _gh_worktree_has_unpushed "$worktree_path"; then
		local branch
		branch=$(git -C "$worktree_path" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
		gum log --level warn "branch '${branch}' has unpushed commits — they remain in the reflog"
	fi

	git -C "$worktree_path" worktree remove -f "$worktree_path" 2>/dev/null || true
}

# Resolve the git repository root directory
#
# Writes the result into the nameref; returns 1 and logs an error on failure.
#
# Usage: _git_repo_path <var_ref>
_git_repo_path() {
	local -n _git_dir_ref="$1"
	_git_dir_ref=$(git rev-parse --show-toplevel 2>/dev/null || true)
	if [[ -z "$_git_dir_ref" ]]; then
		gum log --level error "Not inside a git repository"
		return 1
	fi
}

# Parse a single numeric ID from positional arguments
#
# Accepts one numeric value (optionally prefixed with #). Flags and extra
# positional arguments are rejected. Used by all three subcommands (pr, issue,
# run) so the logic lives here rather than being duplicated in each script.
#
# Usage: _parse_number_arg <var_ref> [args...]
_parse_number_arg() {
	local -n _pna_num="$1"
	shift

	local _pna_raw=("$@")
	local _pna_i=0

	while [[ $_pna_i -lt ${#_pna_raw[@]} ]]; do
		local _pna_arg="${_pna_raw[$_pna_i]}"
		case "$_pna_arg" in
		-*)
			gum log --level error "unknown flag '$_pna_arg'"
			return 1
			;;
		*)
			local _pna_stripped="${_pna_arg#\#}"
			if [[ -z "$_pna_num" && "$_pna_stripped" =~ ^[0-9]+$ ]]; then
				# shellcheck disable=SC2034 # nameref: set by caller
				_pna_num="$_pna_stripped"
			else
				gum log --level error "unexpected argument '$_pna_arg'"
				return 1
			fi
			;;
		esac
		((++_pna_i))
	done
}

# Split arguments on the first -- separator
#
# Everything before -- goes into before_ref; everything after into after_ref.
#
# Usage: _split_on_separator before_ref after_ref [args...]
_split_on_separator() {
	local -n _before_ref="$1"
	local -n _after_ref="$2"
	shift 2

	_before_ref=()
	_after_ref=()

	while [[ $# -gt 0 ]]; do
		if [[ "$1" == "--" ]]; then
			shift
			_after_ref=("$@")
			return 0
		fi
		_before_ref+=("$1")
		shift
	done
}

# Run a command (or $SHELL) inside the worktree.
#
# Changes directory into worktree_path (permanent for this process).
# All worktrees persist until explicitly removed via the 'rm' subcommand.
#
# Usage: _gh_worktree_run <worktree_path> [cmd...]
_gh_worktree_run() {
	local worktree_path="$1"
	shift
	local cmd=("$@")

	if [[ -z "${GH_CLAUDE_DEFAULT_SESSION_ID:-}" ]] && command -v openssl &>/dev/null; then
		export GH_CLAUDE_DEFAULT_SESSION_ID=$(_uuidv5 "$(basename "$worktree_path")")
	fi

	cd "$worktree_path"

	if [[ ${#cmd[@]} -gt 0 ]]; then
		"${cmd[@]}"
	else
		"$SHELL"
	fi
}

# Resolve the absolute path for a worktree
#
# Usage: _gh_worktree_path <prefix> <id>
# Stdout: worktree path
_gh_worktree_path() {
	local prefix="$1"
	local id="$2"

	local cwd=""
	_git_repo_path cwd || return 1
	local base_dir
	base_dir=$(_gh_worktree_base_dir "$cwd")
	printf '%s/%s-%s' "$base_dir" "$prefix" "$id"
}

# When executed directly (not sourced), dispatch to the named function.
#
# Usage: gh_worktree.sh create <args...>
#        gh_worktree.sh remove <worktree_path>
main() {
	local cmd
	cmd="${1:-}"
	shift || true

	case $cmd in
	create)
		_gh_worktree_create "$@"
		;;
	remove)
		_gh_worktree_remove "$@"
		;;
	*)
		gum log --level error "unknown command '${cmd}'"
		exit 1
		;;
	esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
