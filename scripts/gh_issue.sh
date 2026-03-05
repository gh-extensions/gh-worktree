#!/usr/bin/env bash

[ -z "${DEBUG:-}" ] || set -x

set -euo pipefail

# Print usage for the issue subcommand to stdout
#
# Usage: _show_issue_help
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
# Usage: _gh_issue [ISSUE_NUMBER] [-- command]
_gh_issue() {
	case "${1:-}" in
	--help | -h | help)
		_show_issue_help
		return 0
		;;
	esac

	local args=() passthrough=()
	_split_on_separator args passthrough "$@"

	local issue_number=""
	_parse_number_arg issue_number "${args[@]}"

	if [[ -z "$issue_number" ]]; then
		gum log --level error "No issue number provided"
		gum log --level info "Usage: gh worktree issue <ISSUE_NUMBER> [-- <command>]"
		return 1
	fi

	local cwd=""
	_git_repo_path cwd || return 1

	local default_branch
	default_branch=$(git -C "$cwd" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null || true)
	default_branch="${default_branch#refs/remotes/origin/}"
	if [[ -z "$default_branch" ]]; then
		default_branch=$(gum spin --title "Fetching default branch..." -- \
			gh repo view --json defaultBranchRef -q '.defaultBranchRef.name' || true)
	fi
	if [[ -z "$default_branch" ]]; then
		default_branch="main"
	fi

	local worktree_path
	# shellcheck disable=SC2154 # _gh_worktree_source_dir is set by the sourcing script
	worktree_path=$(gum spin --show-error --title "Creating worktree for GitHub issue #${issue_number}..." -- \
		"$_gh_worktree_source_dir/scripts/gh_worktree.sh" create "$cwd" "issue-$issue_number" "$default_branch" "" "")

	if [[ -z "$worktree_path" ]]; then
		gum log --level error "Failed to create worktree for GitHub issue #${issue_number}"
		return 1
	fi

	_gh_worktree_run "$worktree_path" "${passthrough[@]}"
}
