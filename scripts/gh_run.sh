#!/usr/bin/env bash

[ -z "${DEBUG:-}" ] || set -x

set -euo pipefail

# Print usage for the run subcommand to stdout
#
# Usage: _show_run_help
_show_run_help() {
	cat <<'EOF'
gh worktree run - Open an isolated worktree for a workflow run

USAGE:
    gh worktree run <RUN_ID>     [-- <command>]
    gh worktree run rm <RUN_ID>

DESCRIPTION:
    Fetches the workflow run's head branch and SHA, creates a git worktree
    pinned to the exact commit that triggered the run, and runs the given
    command inside the worktree (or opens $SHELL when no command is given).

    The worktree persists until explicitly removed with the 'rm' command.

COMMANDS:
    rm      Remove the worktree associated with the workflow run. Dirty
            changes are auto-stashed before removal.

EXAMPLES:
    gh worktree run 123
    gh worktree run 123 -- nvim
    gh worktree run rm 123
EOF
}

# Run worktree subcommand
#
# Fetches the run's head branch and SHA, creates a worktree pinned to the
# exact commit, and runs the command inside.
#
# Usage: _gh_run [RUN_ID] [-- command]
#        _gh_run rm <RUN_ID>
_gh_run() {
	case "${1:-}" in
	--help | -h | help)
		_show_run_help
		return 0
		;;
	rm)
		shift
		local run_id=""
		_parse_number_arg run_id "$@" || return 1
		if [[ -z "$run_id" ]]; then
			gum log --level error "No run ID provided for removal"
			return 1
		fi

		local worktree_path
		worktree_path=$(_gh_worktree_path "run" "$run_id") || return 1

		if [[ ! -d "$worktree_path" ]]; then
			gum log --level warn "Worktree for workflow run #${run_id} not found at: ${worktree_path}"
			return 0
		fi

		gum spin --title "Removing worktree for workflow run #${run_id}..." -- \
			"$_gh_worktree_source_dir/scripts/gh_worktree.sh" remove "$worktree_path"
		return 0
		;;
	esac

	local args=() passthrough=()
	_split_on_separator args passthrough "$@"

	local run_id=""
	_parse_number_arg run_id "${args[@]}"

	if [[ -z "$run_id" ]]; then
		gum log --level error "No run ID provided"
		gum log --level info "Usage: gh worktree run <RUN_ID> [-- <command>]"
		return 1
	fi

	local cwd=""
	_git_repo_path cwd || return 1

	local meta
	meta=$(gum spin --title "Fetching GitHub workflow run #${run_id} metadata..." -- \
		gh run view "$run_id" --json headBranch,headSha || true)

	if [[ -z "$meta" ]]; then
		gum log --level error "Failed to fetch GitHub workflow run #${run_id}"
		return 1
	fi

	local head_sha
	head_sha=$(printf '%s' "$meta" | jq -r '.headSha')
	local head_branch
	head_branch=$(printf '%s' "$meta" | jq -r '.headBranch')

	local name="run-${run_id}"
	local worktree_path
	# shellcheck disable=SC2154 # _gh_worktree_source_dir is set by the sourcing script
	worktree_path=$(gum spin --show-error --title "Creating worktree for GitHub workflow run #${run_id}..." -- \
		"$_gh_worktree_source_dir/scripts/gh_worktree.sh" create "$cwd" "$name" "$head_branch" "$head_sha" "")

	if [[ -z "$worktree_path" ]]; then
		gum log --level error "Failed to create worktree for GitHub workflow run #${run_id}"
		return 1
	fi

	_gh_worktree_run "$worktree_path" "${passthrough[@]}"
}
