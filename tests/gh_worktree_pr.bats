#!/usr/bin/env bats

# Unit tests for gh_worktree_pr.sh
#
# Requires bats-core: https://github.com/bats-core/bats-core
# Run: bats tests/gh_worktree_pr.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"

setup() {
	export HOME="$BATS_TEST_TMPDIR"

	gum() { if [[ "$1" == "log" ]]; then shift; shift; shift; echo "$@"; fi; }
	gh() { echo ""; }
	git() {
		case "$1 $2" in
		"rev-parse --show-toplevel") echo "$BATS_TEST_TMPDIR" ;;
		esac
	}
	export -f gum gh git

	# shellcheck disable=SC2155
	eval "$(
		# shellcheck source=../scripts/gh_worktree.sh
		source "$REPO_ROOT/scripts/gh_worktree.sh"
		# shellcheck source=../scripts/gh_worktree_pr.sh
		source "$REPO_ROOT/scripts/gh_worktree_pr.sh"
		declare -f _parse_worktree_pr_args _show_pr_help _worktree_pr \
			_split_args _git_repo_path _worktree_create _run_in_worktree
	)"
}

# ---------------------------------------------------------------------------
# _parse_worktree_pr_args
# ---------------------------------------------------------------------------

@test "_parse_worktree_pr_args: captures PR number from positional arg" {
	local number=""
	_parse_worktree_pr_args number 42

	[[ "$number" == "42" ]]
}

@test "_parse_worktree_pr_args: strips leading # from PR number" {
	local number=""
	_parse_worktree_pr_args number "#42"

	[[ "$number" == "42" ]]
}

@test "_parse_worktree_pr_args: defaults to empty when no args given" {
	local number=""
	_parse_worktree_pr_args number

	[[ -z "$number" ]]
}

@test "_parse_worktree_pr_args: returns error for unknown flags" {
	local number=""
	run _parse_worktree_pr_args number --draft

	[[ "$status" -eq 1 ]]
	[[ "$output" == *"unknown flag '--draft'"* ]]
}

@test "_parse_worktree_pr_args: returns error for unexpected non-numeric arg" {
	local number=""
	run _parse_worktree_pr_args number foo

	[[ "$status" -eq 1 ]]
	[[ "$output" == *"unexpected argument 'foo'"* ]]
}

@test "_parse_worktree_pr_args: returns error for second positional arg" {
	local number=""
	run _parse_worktree_pr_args number 42 99

	[[ "$status" -eq 1 ]]
	[[ "$output" == *"unexpected argument '99'"* ]]
}

# ---------------------------------------------------------------------------
# _show_pr_help
# ---------------------------------------------------------------------------

@test "_show_pr_help: prints help text" {
	run _show_pr_help

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"pr"* ]]
	[[ "$output" == *"PR_NUMBER"* ]]
}

# ---------------------------------------------------------------------------
# _worktree_pr
# ---------------------------------------------------------------------------

@test "_worktree_pr: shows help with --help flag" {
	run _worktree_pr --help

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"pr"* ]]
}

@test "_worktree_pr: errors when no PR number provided" {
	run _worktree_pr

	[[ "$status" -eq 1 ]]
}

@test "_worktree_pr: errors when metadata fetch fails" {
	gum() {
		case "$1" in
		spin)
			while [[ $# -gt 0 && "$1" != "--" ]]; do shift; done
			[[ $# -gt 0 ]] && shift
			"$@"
			;;
		log) shift; shift; shift; echo "$@" ;;
		esac
	}
	export -f gum

	gh() { return 1; }
	export -f gh

	run _worktree_pr 42

	[[ "$status" -eq 1 ]]
	[[ "$output" == *"Failed to fetch pull request"* ]]
}

@test "_worktree_pr: calls _worktree_create and _run_in_worktree with correct args" {
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

	gh() {
		case "$1 $2" in
		"pr view") printf '{"headRefName":"feature-branch"}' ;;
		esac
	}
	export -f gh

	_worktree_create() {
		echo "ARGS:cwd=$1 name=$2 remote_ref=$3 sha=$4 branch=$5"
	}

	_run_in_worktree() {
		echo "RUN:path=$1"
	}

	run _worktree_pr 42

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"name=pull-42"* ]]
	[[ "$output" == *"remote_ref=feature-branch"* ]]
	[[ "$output" == *"branch=feature-branch"* ]]
	[[ "$output" == *"RUN:path="* ]]
}

@test "_worktree_pr: forwards passthrough command to _run_in_worktree" {
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

	gh() {
		case "$1 $2" in
		"pr view") printf '{"headRefName":"feature-branch"}' ;;
		esac
	}
	export -f gh

	_worktree_create() { echo "/tmp/worktree"; }

	_run_in_worktree() {
		shift
		echo "CMD:$*"
	}

	run _worktree_pr 42 -- gh ai pr chat 42

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"CMD:gh ai pr chat 42"* ]]
}
