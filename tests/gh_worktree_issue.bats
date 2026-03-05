#!/usr/bin/env bats

# Unit tests for gh_worktree_issue.sh
#
# Requires bats-core: https://github.com/bats-core/bats-core
# Run: bats tests/gh_worktree_issue.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"

setup() {
	export HOME="$BATS_TEST_TMPDIR"

	gum() { if [[ "$1" == "log" ]]; then shift; shift; shift; echo "$@"; fi; }
	gh() { echo ""; }
	git() {
		local _args=("$@")
		[[ "${_args[0]}" == "-C" ]] && _args=("${_args[@]:2}")
		case "${_args[0]} ${_args[1]}" in
		"rev-parse --show-toplevel") echo "$BATS_TEST_TMPDIR" ;;
		"symbolic-ref refs/remotes/origin/HEAD") echo "refs/remotes/origin/main" ;;
		esac
	}
	export -f gum gh git

	# shellcheck disable=SC2155
	eval "$(
		# shellcheck source=../scripts/gh_worktree.sh
		source "$REPO_ROOT/scripts/gh_worktree.sh"
		# shellcheck source=../scripts/gh_worktree_issue.sh
		source "$REPO_ROOT/scripts/gh_worktree_issue.sh"
		declare -f _parse_worktree_issue_args _show_issue_help _worktree_issue \
			_split_args _git_repo_path _worktree_create _run_in_worktree
	)"
}

# ---------------------------------------------------------------------------
# _parse_worktree_issue_args
# ---------------------------------------------------------------------------

@test "_parse_worktree_issue_args: captures issue number from positional arg" {
	local number=""
	_parse_worktree_issue_args number 55

	[[ "$number" == "55" ]]
}

@test "_parse_worktree_issue_args: strips leading # from issue number" {
	local number=""
	_parse_worktree_issue_args number "#55"

	[[ "$number" == "55" ]]
}

@test "_parse_worktree_issue_args: defaults to empty when no args given" {
	local number=""
	_parse_worktree_issue_args number

	[[ -z "$number" ]]
}

@test "_parse_worktree_issue_args: returns error for unknown flags" {
	local number=""
	run _parse_worktree_issue_args number --foo

	[[ "$status" -eq 1 ]]
	[[ "$output" == *"unknown flag '--foo'"* ]]
}

@test "_parse_worktree_issue_args: returns error for unexpected non-numeric arg" {
	local number=""
	run _parse_worktree_issue_args number foo

	[[ "$status" -eq 1 ]]
	[[ "$output" == *"unexpected argument 'foo'"* ]]
}

@test "_parse_worktree_issue_args: returns error for second positional arg" {
	local number=""
	run _parse_worktree_issue_args number 55 99

	[[ "$status" -eq 1 ]]
	[[ "$output" == *"unexpected argument '99'"* ]]
}

# ---------------------------------------------------------------------------
# _show_issue_help
# ---------------------------------------------------------------------------

@test "_show_issue_help: prints help text" {
	run _show_issue_help

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"issue"* ]]
	[[ "$output" == *"ISSUE_NUMBER"* ]]
}

# ---------------------------------------------------------------------------
# _worktree_issue
# ---------------------------------------------------------------------------

@test "_worktree_issue: shows help with --help flag" {
	run _worktree_issue --help

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"issue"* ]]
}

@test "_worktree_issue: errors when no issue number provided" {
	run _worktree_issue

	[[ "$status" -eq 1 ]]
}

@test "_worktree_issue: calls _worktree_create with correct args" {
	gum() {
		case "$1" in
		spin)
			while [[ $# -gt 0 && "$1" != "--" ]]; do shift; done
			[[ $# -gt 0 ]] && shift
			"$@"
			;;
		log) ;;
		esac
	}
	export -f gum

	_worktree_create() {
		echo "ARGS:cwd=$1 name=$2 remote_ref=$3 sha=$4 branch=$5"
	}

	_run_in_worktree() { echo "RUN:path=$1"; }

	run _worktree_issue 55

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"name=issue-55"* ]]
	[[ "$output" == *"remote_ref=main"* ]]
	[[ "$output" == *"branch="* ]]
}

@test "_worktree_issue: forwards passthrough command to _run_in_worktree" {
	gum() {
		case "$1" in
		spin)
			while [[ $# -gt 0 && "$1" != "--" ]]; do shift; done
			[[ $# -gt 0 ]] && shift
			"$@"
			;;
		log) ;;
		esac
	}
	export -f gum

	_worktree_create() { echo "/tmp/worktree"; }

	_run_in_worktree() {
		shift
		echo "CMD:$*"
	}

	run _worktree_issue 55 -- gh ai issue chat 55

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"CMD:gh ai issue chat 55"* ]]
}
