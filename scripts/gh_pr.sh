#!/usr/bin/env bash

[ -z "${DEBUG:-}" ] || set -x

set -euo pipefail

# Print usage for the pr subcommand to stdout
#
# Usage: _show_pr_help
_show_pr_help() {
	cat <<'EOF'
gh worktree pr - Open an isolated worktree for a pull request

USAGE:
    gh worktree pr <PR_NUMBER> [-- <command>]

DESCRIPTION:
    Fetches the pull request head branch, creates a git worktree tracking it,
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
# Fetches the pull request head branch, creates a worktree, and runs the command inside.
#
# Usage: _gh_pr [PR_NUMBER] [-- command]
_gh_pr() {
	case "${1:-}" in
	--help | -h | help)
		_show_pr_help
		return 0
		;;
	esac

	local args=() passthrough=()
	_split_on_separator args passthrough "$@"

	local pr_number=""
	_parse_number_arg pr_number "${args[@]}"

	if [[ -z "$pr_number" ]]; then
		gum log --level error "No pull request number provided"
		gum log --level info "Usage: gh worktree pr <PR_NUMBER> [-- <command>]"
		return 1
	fi

	local cwd=""
	_git_repo_path cwd || return 1

	local meta
	meta=$(gum spin --title "Fetching GitHub pull request #${pr_number} metadata..." -- \
		gh pr view "$pr_number" --json headRefName || true)

	if [[ -z "$meta" ]]; then
		gum log --level error "Failed to fetch GitHub pull request #${pr_number}"
		return 1
	fi

	local head_ref
	head_ref=$(printf '%s' "$meta" | jq -r '.headRefName')

	local worktree_path
	# shellcheck disable=SC2154 # _gh_worktree_source_dir is set by the sourcing script
	worktree_path=$(gum spin --show-error --title "Creating worktree for GitHub pull request #${pr_number}..." -- \
		"$_gh_worktree_source_dir/scripts/gh_worktree.sh" create "$cwd" "pull-$pr_number" "$head_ref" "" "$head_ref")

	if [[ -z "$worktree_path" ]]; then
		gum log --level error "Failed to create worktree for GitHub pull request #${pr_number}"
		return 1
	fi

	_gh_worktree_run "$worktree_path" "${passthrough[@]}"
}
