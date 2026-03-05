#!/usr/bin/env bats

# Unit tests for gh_pr.sh
#
# Requires bats-core: https://github.com/bats-core/bats-core
# Run: bats tests/gh_pr.bats

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
		case "$1 $2" in
		"rev-parse --show-toplevel") echo "$BATS_TEST_TMPDIR" ;;
		esac
	}
	export -f gum gh git

	# shellcheck disable=SC2155
	eval "$(
		# shellcheck source=../scripts/gh_worktree.sh
		source "$REPO_ROOT/scripts/gh_worktree.sh"
		# shellcheck source=../scripts/gh_pr.sh
		source "$REPO_ROOT/scripts/gh_pr.sh"
		declare -f _parse_number_arg _show_pr_help _gh_pr \
			_split_on_separator _git_repo_path _gh_worktree_create _gh_worktree_remove _gh_worktree_run
	)"
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
# _gh_pr
# ---------------------------------------------------------------------------

@test "_gh_pr: shows help with --help flag" {
	run _gh_pr --help

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"pr"* ]]
}

@test "_gh_pr: errors when no PR number provided" {
	run _gh_pr

	[[ "$status" -eq 1 ]]
}

@test "_gh_pr: accepts #-prefixed PR number" {
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

	_gh_worktree_create() { echo "ARGS:name=$2"; }
	export -f _gh_worktree_create

	_gh_worktree_run() { echo "RUN:path=$1"; }

	run _gh_pr "#42"

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"name=pull-42"* ]]
}

@test "_gh_pr: errors when metadata fetch fails" {
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

	run _gh_pr 42

	[[ "$status" -eq 1 ]]
	[[ "$output" == *"Failed to fetch GitHub pull request"* ]]
}

@test "_gh_pr: errors when worktree creation returns empty path" {
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

	gh() {
		case "$1 $2" in
		"pr view") printf '{"headRefName":"feature-branch"}' ;;
		esac
	}
	export -f gh

	_gh_worktree_create() { :; }
	export -f _gh_worktree_create

	run _gh_pr 42

	[[ "$status" -eq 1 ]]
	[[ "$output" == *"Failed to create worktree"* ]]
}

@test "_gh_pr: calls _gh_worktree_create and _gh_worktree_run with correct args" {
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

	_gh_worktree_create() {
		echo "ARGS:cwd=$1 name=$2 remote_ref=$3 sha=$4 branch=$5"
	}
	export -f _gh_worktree_create

	_gh_worktree_run() {
		echo "RUN:path=$1"
	}

	run _gh_pr 42

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"name=pull-42"* ]]
	[[ "$output" == *"remote_ref=feature-branch"* ]]
	[[ "$output" == *"branch=feature-branch"* ]]
	[[ "$output" == *"RUN:path="* ]]
}

@test "_gh_pr: forwards passthrough command to _gh_worktree_run" {
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

	_gh_worktree_create() { echo "/tmp/worktree"; }
	export -f _gh_worktree_create

	_gh_worktree_run() {
		shift
		echo "CMD:$*"
	}

	run _gh_pr 42 -- gh ai pr chat 42

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"CMD:gh ai pr chat 42"* ]]
}
