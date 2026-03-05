#!/usr/bin/env bats

# Unit tests for gh_run.sh
#
# Requires bats-core: https://github.com/bats-core/bats-core
# Run: bats tests/gh_run.bats

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
		# shellcheck source=../scripts/gh_run.sh
		source "$REPO_ROOT/scripts/gh_run.sh"
		declare -f _parse_run_args _show_run_help _gh_run_exec \
			_split_args _git_repo_path _worktree_create _run_in_worktree
	)"
}

# ---------------------------------------------------------------------------
# _parse_run_args
# ---------------------------------------------------------------------------

@test "_parse_run_args: captures run ID from positional arg" {
	local id=""
	_parse_run_args id 123

	[[ "$id" == "123" ]]
}

@test "_parse_run_args: strips leading # from run ID" {
	local id=""
	_parse_run_args id "#123"

	[[ "$id" == "123" ]]
}

@test "_parse_run_args: defaults to empty when no args given" {
	local id=""
	_parse_run_args id

	[[ -z "$id" ]]
}

@test "_parse_run_args: returns error for unknown flags" {
	local id=""
	run _parse_run_args id --foo

	[[ "$status" -eq 1 ]]
	[[ "$output" == *"unknown flag '--foo'"* ]]
}

@test "_parse_run_args: returns error for unexpected non-numeric arg" {
	local id=""
	run _parse_run_args id foo

	[[ "$status" -eq 1 ]]
	[[ "$output" == *"unexpected argument 'foo'"* ]]
}

@test "_parse_run_args: returns error for second positional arg" {
	local id=""
	run _parse_run_args id 123 456

	[[ "$status" -eq 1 ]]
	[[ "$output" == *"unexpected argument '456'"* ]]
}

# ---------------------------------------------------------------------------
# _show_run_help
# ---------------------------------------------------------------------------

@test "_show_run_help: prints help text" {
	run _show_run_help

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"run"* ]]
	[[ "$output" == *"RUN_ID"* ]]
}

# ---------------------------------------------------------------------------
# _gh_run_exec
# ---------------------------------------------------------------------------

@test "_gh_run_exec: shows help with --help flag" {
	run _gh_run_exec --help

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"run"* ]]
}

@test "_gh_run_exec: errors when no run ID provided" {
	run _gh_run_exec

	[[ "$status" -eq 1 ]]
}

@test "_gh_run_exec: errors when metadata fetch fails" {
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

	run _gh_run_exec 123

	[[ "$status" -eq 1 ]]
	[[ "$output" == *"Failed to fetch workflow run"* ]]
}

@test "_gh_run_exec: calls _worktree_create with correct args including SHA" {
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
		"run view") printf '{"headBranch":"main","headSha":"abc123def"}' ;;
		esac
	}
	export -f gh

	_worktree_create() {
		echo "ARGS:cwd=$1 name=$2 remote_ref=$3 sha=$4 branch=$5"
	}

	_run_in_worktree() { echo "RUN:path=$1"; }

	run _gh_run_exec 123

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"name=run-123"* ]]
	[[ "$output" == *"remote_ref=main"* ]]
	[[ "$output" == *"sha=abc123def"* ]]
	[[ "$output" == *"branch="* ]]
}

@test "_gh_run_exec: forwards passthrough command to _run_in_worktree" {
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
		"run view") printf '{"headBranch":"main","headSha":"abc123def"}' ;;
		esac
	}
	export -f gh

	_worktree_create() { echo "/tmp/worktree"; }

	_run_in_worktree() {
		shift
		echo "CMD:$*"
	}

	run _gh_run_exec 123 -- gh ai run chat 123

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"CMD:gh ai run chat 123"* ]]
}
