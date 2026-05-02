#!/usr/bin/env bats

# Unit tests for gh_issue.sh
#
# Requires bats-core: https://github.com/bats-core/bats-core
# Run: bats tests/gh_issue.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"

setup() {
	export HOME="$BATS_TEST_TMPDIR"
	# Point to a stub scripts/ dir so gh_worktree.sh dispatches to exported
	# _gh_worktree_* function mocks without running real git commands.
	export _gh_worktree_source_dir="$BATS_TEST_TMPDIR"
	mkdir -p "$BATS_TEST_TMPDIR/scripts"
	printf '#!/usr/bin/env bash\ncmd="${1:-}"; shift\n"_gh_worktree_${cmd}" "$@"\n' \
		> "$BATS_TEST_TMPDIR/scripts/gh_worktree.sh"
	chmod +x "$BATS_TEST_TMPDIR/scripts/gh_worktree.sh"

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
		# shellcheck source=../scripts/gh_issue.sh
		source "$REPO_ROOT/scripts/gh_issue.sh"
		declare -f _parse_number_arg _show_issue_help _gh_issue \
			_split_on_separator _git_repo_path _gh_worktree_create _gh_worktree_remove _gh_worktree_run _gh_worktree_path
	)"
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
# _gh_issue
# ---------------------------------------------------------------------------

@test "_gh_issue: shows help with --help flag" {
	run _gh_issue --help

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"issue"* ]]
}

@test "_gh_issue: errors when no issue number provided" {
	run _gh_issue

	[[ "$status" -eq 1 ]]
}

@test "_gh_issue: accepts #-prefixed issue number" {
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

	_gh_worktree_create() { echo "ARGS:path=$1"; }
	export -f _gh_worktree_create

	_gh_worktree_run() { echo "RUN:path=$1"; }

	run _gh_issue "#55"

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"path="*"/issue-55"* ]]
}

@test "_gh_issue: errors when worktree creation returns empty path" {
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

	_gh_worktree_create() { :; }
	export -f _gh_worktree_create

	run _gh_issue 55

	[[ "$status" -eq 1 ]]
	[[ "$output" == *"Failed to create worktree"* ]]
}

@test "_gh_issue: falls back to gh repo view when origin/HEAD not set" {
	git() {
		local _args=("$@")
		[[ "${_args[0]}" == "-C" ]] && _args=("${_args[@]:2}")
		case "${_args[0]} ${_args[1]}" in
		"rev-parse --show-toplevel") echo "$BATS_TEST_TMPDIR" ;;
		"symbolic-ref refs/remotes/origin/HEAD") return 1 ;;
		esac
	}
	export -f git

	gh() {
		case "$1 $2" in
		"repo view") echo "develop" ;;
		esac
	}
	export -f gh

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

	_gh_worktree_create() { echo "ARGS:remote_ref=$2"; }
	export -f _gh_worktree_create

	_gh_worktree_run() { echo "RUN:path=$1"; }

	run _gh_issue 55

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"remote_ref=develop"* ]]
}

@test "_gh_issue: falls back to main when all branch detection fails" {
	git() {
		local _args=("$@")
		[[ "${_args[0]}" == "-C" ]] && _args=("${_args[@]:2}")
		case "${_args[0]} ${_args[1]}" in
		"rev-parse --show-toplevel") echo "$BATS_TEST_TMPDIR" ;;
		"symbolic-ref refs/remotes/origin/HEAD") return 1 ;;
		esac
	}
	export -f git

	gh() { return 1; }
	export -f gh

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

	_gh_worktree_create() { echo "ARGS:remote_ref=$2"; }
	export -f _gh_worktree_create

	_gh_worktree_run() { echo "RUN:path=$1"; }

	run _gh_issue 55

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"remote_ref=main"* ]]
}

@test "_gh_issue: calls _gh_worktree_create with correct args" {
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

	_gh_worktree_create() {
		echo "ARGS:path=$1 remote_ref=$2 sha=$3 branch=$4"
	}
	export -f _gh_worktree_create

	_gh_worktree_run() { echo "RUN:path=$1"; }

	run _gh_issue 55

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"path="*"/issue-55"* ]]
	[[ "$output" == *"remote_ref=main"* ]]
	[[ "$output" == *"branch="* ]]
}

@test "_gh_issue: rm calls _gh_worktree_remove with correct path" {
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

	_gh_worktree_base_dir() { echo "$BATS_TEST_TMPDIR/worktrees"; }
	export -f _gh_worktree_base_dir

	_gh_worktree_remove() { echo "REMOVE:path=$1"; }
	export -f _gh_worktree_remove

	# Create the directory so [[ -d ... ]] succeeds
	mkdir -p "$BATS_TEST_TMPDIR/worktrees/issue-55"

	run _gh_issue rm 55

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"REMOVE:path=$BATS_TEST_TMPDIR/worktrees/issue-55"* ]]
}

@test "_gh_issue: forwards passthrough command to _gh_worktree_run" {
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

	_gh_worktree_create() { echo "/tmp/worktree"; }
	export -f _gh_worktree_create

	_gh_worktree_run() {
		shift
		echo "CMD:$*"
	}

	run _gh_issue 55 -- gh ai issue chat 55

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"CMD:gh ai issue chat 55"* ]]
}
