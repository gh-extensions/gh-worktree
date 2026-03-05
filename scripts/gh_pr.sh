#!/usr/bin/env bash

set -euo pipefail

# Parse PR worktree arguments
#
# Extracts the PR number (first positional numeric arg, strips leading #).
# Unknown flags produce an error.
#
# Usage: _parse_pr_args num_ref [args...]
_parse_pr_args() {
	local -n _pwpa_num="$1"
	shift

	local _pwpa_raw=("$@")
	local _pwpa_i=0

	while [[ $_pwpa_i -lt ${#_pwpa_raw[@]} ]]; do
		local _pwpa_arg="${_pwpa_raw[$_pwpa_i]}"
		case "$_pwpa_arg" in
		-*)
			gum log --level error "unknown flag '$_pwpa_arg'"
			return 1
			;;
		*)
			local _pwpa_stripped="${_pwpa_arg#\#}"
			if [[ -z "$_pwpa_num" && "$_pwpa_stripped" =~ ^[0-9]+$ ]]; then
				# shellcheck disable=SC2034 # nameref: set by caller
				_pwpa_num="$_pwpa_stripped"
			else
				gum log --level error "unexpected argument '$_pwpa_arg'"
				return 1
			fi
			;;
		esac
		((++_pwpa_i))
	done
}

# PR worktree help
_show_pr_help() {
	cat <<'EOF'
gh worktree pr - Open an isolated worktree for a pull request

USAGE:
    gh worktree pr <PR_NUMBER> [-- <command>]

DESCRIPTION:
    Fetches the PR head branch, creates a git worktree tracking it,
    and runs the given command inside the worktree (or opens $SHELL when
    no command is given). The worktree is removed when the command exits.

EXAMPLES:
    gh worktree pr 42
    gh worktree pr 42 -- gh ai pr chat 42
    gh worktree pr 42 -- nvim
EOF
}

# PR worktree subcommand
#
# Fetches the PR head branch, creates a worktree, and runs the command inside.
#
# Usage: _gh_pr_exec [PR_NUMBER] [-- command]
_gh_pr_exec() {
	case "${1:-}" in
	--help | -h | help)
		_show_pr_help
		return 0
		;;
	esac

	local args=() cmd=()
	_split_args args cmd "$@"

	local pr_number=""
	_parse_pr_args pr_number "${args[@]}"

	if [[ -z "$pr_number" ]]; then
		gum log --level error "No pull request number provided"
		gum log --level info "Usage: gh worktree pr <number> [-- <command>]"
		return 1
	fi

	local cwd=""
	_git_repo_path cwd || return 1

	local meta
	meta=$(gum spin --title "Fetching pull request #${pr_number} metadata..." -- \
		gh pr view "$pr_number" --json headRefName 2>/dev/null || true)

	if [[ -z "$meta" ]]; then
		gum log --level error "Failed to fetch pull request #${pr_number}"
		return 1
	fi

	local head_ref
	head_ref=$(printf '%s' "$meta" | jq -r '.headRefName')

	local name="pull-${pr_number}"
	gum log --level info "Creating worktree for PR #${pr_number}..."
	local worktree_path
	worktree_path=$(_worktree_create "$cwd" "$name" "$head_ref" "" "$head_ref")

	_run_in_worktree "$worktree_path" "${cmd[@]}"
}
