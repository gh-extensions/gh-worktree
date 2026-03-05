#!/usr/bin/env bash

set -euo pipefail

# Parse issue worktree arguments
#
# Extracts the issue number (first positional numeric arg, strips leading #).
# Unknown flags produce an error.
#
# Usage: _parse_worktree_issue_args num_ref [args...]
_parse_worktree_issue_args() {
	local -n _pwia_num="$1"
	shift

	local _pwia_raw=("$@")
	local _pwia_i=0

	while [[ $_pwia_i -lt ${#_pwia_raw[@]} ]]; do
		local _pwia_arg="${_pwia_raw[$_pwia_i]}"
		case "$_pwia_arg" in
		-*)
			gum log --level error "unknown flag '$_pwia_arg'"
			return 1
			;;
		*)
			local _pwia_stripped="${_pwia_arg#\#}"
			if [[ -z "$_pwia_num" && "$_pwia_stripped" =~ ^[0-9]+$ ]]; then
				# shellcheck disable=SC2034 # nameref: set by caller
				_pwia_num="$_pwia_stripped"
			else
				gum log --level error "unexpected argument '$_pwia_arg'"
				return 1
			fi
			;;
		esac
		((++_pwia_i))
	done
}

# Issue worktree help
_show_issue_help() {
	cat <<'EOF'
gh worktree issue - Open an isolated worktree for an issue

USAGE:
    gh worktree issue <ISSUE_NUMBER> [-- <command>]

DESCRIPTION:
    Creates a new branch from the default branch, sets up a git worktree,
    and runs the given command inside the worktree (or opens $SHELL when
    no command is given). The worktree is removed when the command exits.

EXAMPLES:
    gh worktree issue 55
    gh worktree issue 55 -- gh ai issue chat 55
    gh worktree issue 55 -- nvim
EOF
}

# Issue worktree subcommand
#
# Creates a new branch from the default branch, creates a worktree, and
# runs the command inside.
#
# Usage: _worktree_issue [ISSUE_NUMBER] [-- command]
_worktree_issue() {
	case "${1:-}" in
	--help | -h | help)
		_show_issue_help
		return 0
		;;
	esac

	local args=() cmd=()
	_split_args args cmd "$@"

	local issue_number=""
	_parse_worktree_issue_args issue_number "${args[@]}"

	if [[ -z "$issue_number" ]]; then
		gum log --level error "No issue number provided"
		gum log --level info "Usage: gh worktree issue <number> [-- <command>]"
		return 1
	fi

	local cwd=""
	_git_repo_path cwd || return 1

	local default_branch
	default_branch=$(git -C "$cwd" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' ||
		gh repo view --json defaultBranchRef -q '.defaultBranchRef.name' 2>/dev/null ||
		echo "main")

	local name="issue-${issue_number}"
	local worktree_path
	worktree_path=$(gum spin --title "Creating worktree for issue #${issue_number}..." -- \
		_worktree_create "$cwd" "$name" "$default_branch" "" "")

	_run_in_worktree "$worktree_path" "${cmd[@]}"
}
