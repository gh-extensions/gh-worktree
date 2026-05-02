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
    gh worktree pr <PR_NUMBER>     [-- <command>]
    gh worktree pr rm <PR_NUMBER>

DESCRIPTION:
    Fetches the pull request head branch, creates a git worktree tracking it,
    and runs the given command inside the worktree (or opens $SHELL when
    no command is given).

    The worktree persists until explicitly removed with the 'rm' command.

COMMANDS:
    rm      Remove the worktree associated with the pull request. Dirty
            changes are auto-stashed before removal.

EXAMPLES:
    gh worktree pr 42
    gh worktree pr 42 -- nvim
    gh worktree pr rm 42
EOF
}

# PR worktree subcommand
#
# Fetches the pull request head branch, creates a worktree, and runs the command inside.
#
# Usage: _gh_pr [PR_NUMBER] [-- command]
#        _gh_pr rm <PR_NUMBER>
_gh_pr() {
	case "${1:-}" in
	--help | -h | help)
		_show_pr_help
		return 0
		;;
	rm)
		shift
		local pr_number=""
		_parse_number_arg pr_number "$@" || return 1
		if [[ -z "$pr_number" ]]; then
			gum log --level error "No pull request number provided for removal"
			return 1
		fi

		local worktree_path
		worktree_path=$(_gh_worktree_path "pull" "$pr_number") || return 1

		if [[ ! -d "$worktree_path" ]]; then
			gum log --level warn "Worktree for pull request #${pr_number} not found at: ${worktree_path}"
			return 0
		fi

		gum spin --title "Removing worktree for pull request #${pr_number}..." -- \
			"$_gh_worktree_source_dir/scripts/gh_worktree.sh" remove "$worktree_path"
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
