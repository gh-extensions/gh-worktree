#!/usr/bin/env bats

# Unit tests for gh_run.sh
#
# Requires bats-core: https://github.com/bats-core/bats-core
# Run: bats tests/gh_run.bats

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
		# shellcheck source=../scripts/gh_run.sh
		source "$REPO_ROOT/scripts/gh_run.sh"
		declare -f _parse_number_arg _show_run_help _gh_run \
			_split_on_separator _git_repo_path _gh_worktree_create _gh_worktree_remove _gh_worktree_run \
			_has_gum _gum
	)"
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
# _gh_run
# ---------------------------------------------------------------------------

@test "_gh_run: shows help with --help flag" {
	run _gh_run --help

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"run"* ]]
}

@test "_gh_run: errors when no run ID provided" {
	run _gh_run

	[[ "$status" -eq 1 ]]
}

@test "_gh_run: accepts #-prefixed run ID" {
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
		"run view") printf '{"headBranch":"main","headSha":"abc123"}' ;;
		esac
	}
	export -f gh

	_gh_worktree_create() { echo "ARGS:name=$2"; }
	export -f _gh_worktree_create

	_gh_worktree_run() { echo "RUN:path=$1"; }

	run _gh_run "#123"

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"name=run-123"* ]]
}

@test "_gh_run: errors when metadata fetch fails" {
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

	run _gh_run 123

	[[ "$status" -eq 1 ]]
	[[ "$output" == *"Failed to fetch GitHub workflow run"* ]]
}

@test "_gh_run: errors when worktree creation returns empty path" {
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
		"run view") printf '{"headBranch":"main","headSha":"abc123"}' ;;
		esac
	}
	export -f gh

	_gh_worktree_create() { :; }
	export -f _gh_worktree_create

	run _gh_run 123

	[[ "$status" -eq 1 ]]
	[[ "$output" == *"Failed to create worktree"* ]]
}

@test "_gh_run: calls _gh_worktree_create with correct args including SHA" {
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

	_gh_worktree_create() {
		echo "ARGS:cwd=$1 name=$2 remote_ref=$3 sha=$4 branch=$5"
	}
	export -f _gh_worktree_create

	_gh_worktree_run() { echo "RUN:path=$1"; }

	run _gh_run 123

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"name=run-123"* ]]
	[[ "$output" == *"remote_ref=main"* ]]
	[[ "$output" == *"sha=abc123def"* ]]
	[[ "$output" == *"branch="* ]]
}

@test "_gh_run: forwards passthrough command to _gh_worktree_run" {
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

	_gh_worktree_create() { echo "/tmp/worktree"; }
	export -f _gh_worktree_create

	_gh_worktree_run() {
		shift
		echo "CMD:$*"
	}

	run _gh_run 123 -- gh ai run chat 123

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"CMD:gh ai run chat 123"* ]]
}
