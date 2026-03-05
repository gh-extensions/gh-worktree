#!/usr/bin/env bash

set -euo pipefail

# Parse run worktree arguments
#
# Extracts the run ID (first positional numeric arg, strips leading #).
# Unknown flags produce an error.
#
# Usage: _parse_run_args id_ref [args...]
_parse_run_args() {
	local -n _pwra_id="$1"
	shift

	local _pwra_raw=("$@")
	local _pwra_i=0

	while [[ $_pwra_i -lt ${#_pwra_raw[@]} ]]; do
		local _pwra_arg="${_pwra_raw[$_pwra_i]}"
		case "$_pwra_arg" in
		-*)
			gum log --level error "unknown flag '$_pwra_arg'"
			return 1
			;;
		*)
			local _pwra_stripped="${_pwra_arg#\#}"
			if [[ -z "$_pwra_id" && "$_pwra_stripped" =~ ^[0-9]+$ ]]; then
				# shellcheck disable=SC2034 # nameref: set by caller
				_pwra_id="$_pwra_stripped"
			else
				gum log --level error "unexpected argument '$_pwra_arg'"
				return 1
			fi
			;;
		esac
		((++_pwra_i))
	done
}

# Run worktree help
_show_run_help() {
	cat <<'EOF'
gh worktree run - Open an isolated worktree for a workflow run

USAGE:
    gh worktree run <RUN_ID> [-- <command>]

DESCRIPTION:
    Fetches the workflow run's head branch and SHA, creates a git worktree
    pinned to the exact commit that triggered the run, and runs the given
    command inside the worktree (or opens $SHELL when no command is given).
    The worktree is removed when the command exits.

EXAMPLES:
    gh worktree run 123
    gh worktree run 123 -- gh ai run chat 123
    gh worktree run 123 -- nvim
EOF
}

# Run worktree subcommand
#
# Fetches the run's head branch and SHA, creates a worktree pinned to the
# exact commit, and runs the command inside.
#
# Usage: _gh_run_exec [RUN_ID] [-- command]
_gh_run_exec() {
	case "${1:-}" in
	--help | -h | help)
		_show_run_help
		return 0
		;;
	esac

	local args=() cmd=()
	_split_args args cmd "$@"

	local run_id=""
	_parse_run_args run_id "${args[@]}"

	if [[ -z "$run_id" ]]; then
		gum log --level error "No run ID provided"
		gum log --level info "Usage: gh worktree run <RUN_ID> [-- <command>]"
		return 1
	fi

	local cwd=""
	_git_repo_path cwd || return 1

	local meta
	meta=$(gum spin --title "Fetching GitHub workflow run #${run_id} metadata..." -- \
		gh run view "$run_id" --json headBranch,headSha 2>/dev/null || true)

	if [[ -z "$meta" ]]; then
		gum log --level error "Failed to fetch GitHub workflow run #${run_id}"
		return 1
	fi

	local head_branch head_sha
	head_branch=$(printf '%s' "$meta" | jq -r '.headBranch')
	head_sha=$(printf '%s' "$meta" | jq -r '.headSha')

	local name="run-${run_id}"
	local worktree_path
	worktree_path=$(gum spin --show-error --title "Creating worktree for GitHub workflow run #${run_id}..." -- \
		"$_gh_worktree_source_dir/scripts/gh_worktree.sh" create "$cwd" "$name" "$head_branch" "$head_sha" "")

	if [[ -z "$worktree_path" ]]; then
		gum log --level error "Failed to create worktree for GitHub workflow run #${run_id}"
		return 1
	fi

	_run_in_worktree "$worktree_path" "${cmd[@]}"
}
