#!/usr/bin/env bats

# Unit tests for gh_worktree.sh
#
# Requires bats-core: https://github.com/bats-core/bats-core
# Run: bats tests/gh_worktree.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"

setup() {
	export HOME="$BATS_TEST_TMPDIR"

	# Create a bare "remote" and a local clone
	git init --bare "$BATS_TEST_TMPDIR/remote.git" >/dev/null 2>&1
	git clone "$BATS_TEST_TMPDIR/remote.git" "$BATS_TEST_TMPDIR/repo" >/dev/null 2>&1
	git -C "$BATS_TEST_TMPDIR/repo" config user.email "test@test.com"
	git -C "$BATS_TEST_TMPDIR/repo" config user.name "Test"
	git -C "$BATS_TEST_TMPDIR/repo" config commit.gpgsign false
	git -C "$BATS_TEST_TMPDIR/repo" commit --allow-empty -m "initial" >/dev/null 2>&1
	git -C "$BATS_TEST_TMPDIR/repo" push >/dev/null 2>&1

	# Create a worktree for use in dirty/unpushed/remove tests
	WORKTREE_PATH="$BATS_TEST_TMPDIR/repo/.github/worktrees/issue-1"
	git -C "$BATS_TEST_TMPDIR/repo" worktree add -b issue-1 "$WORKTREE_PATH" HEAD >/dev/null 2>&1
	DEFAULT_BRANCH=$(git -C "$BATS_TEST_TMPDIR/repo" rev-parse --abbrev-ref HEAD)
	git -C "$WORKTREE_PATH" branch --set-upstream-to="origin/${DEFAULT_BRANCH}" >/dev/null 2>&1

	gum() { if [[ "$1" == "log" ]]; then shift; shift; shift; echo "$@"; fi; }
	gh() { :; }
	export -f gum gh

	# shellcheck disable=SC2155
	eval "$(
		# shellcheck source=../scripts/gh_worktree.sh
		source "$REPO_ROOT/scripts/gh_worktree.sh"
		declare -f _gh_worktree_base_dir _gh_worktree_is_dirty _gh_worktree_has_unpushed \
			_gh_worktree_create _gh_worktree_remove _git_repo_path _split_on_separator _gh_worktree_run
	)"
}

teardown() {
	git -C "$BATS_TEST_TMPDIR/repo" worktree prune 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# _gh_worktree_base_dir
# ---------------------------------------------------------------------------

@test "_gh_worktree_base_dir: returns default .github/worktrees relative to cwd" {
	unset GH_WORKTREE_DIR
	gh() { return 1; }
	export -f gh

	run _gh_worktree_base_dir "/repo/root"

	[[ "$status" -eq 0 ]]
	[[ "$output" == "/repo/root/.github/worktrees" ]]
}

@test "_gh_worktree_base_dir: GH_WORKTREE_DIR overrides default" {
	export GH_WORKTREE_DIR="/custom/worktrees"

	run _gh_worktree_base_dir "/repo/root"

	[[ "$status" -eq 0 ]]
	[[ "$output" == "/custom/worktrees" ]]
	unset GH_WORKTREE_DIR
}

@test "_gh_worktree_base_dir: gh config get worktree.dir overrides default" {
	unset GH_WORKTREE_DIR
	gh() { echo ".myworktrees"; }
	export -f gh

	run _gh_worktree_base_dir "/repo/root"

	[[ "$status" -eq 0 ]]
	[[ "$output" == "/repo/root/.myworktrees" ]]
}

@test "_gh_worktree_base_dir: absolute path from gh config is not prefixed with cwd" {
	unset GH_WORKTREE_DIR
	gh() { echo "/abs/path/worktrees"; }
	export -f gh

	run _gh_worktree_base_dir "/repo/root"

	[[ "$status" -eq 0 ]]
	[[ "$output" == "/abs/path/worktrees" ]]
}

# ---------------------------------------------------------------------------
# _split_on_separator
# ---------------------------------------------------------------------------

@test "_split_on_separator: places all args in before when no -- present" {
	local args=() cmd=()
	_split_on_separator args cmd foo bar baz

	[[ "${args[*]}" == "foo bar baz" ]]
	[[ "${#cmd[@]}" -eq 0 ]]
}

@test "_split_on_separator: splits on -- separator" {
	local args=() cmd=()
	_split_on_separator args cmd 42 -- gh ai pr chat 42

	[[ "${args[*]}" == "42" ]]
	[[ "${cmd[*]}" == "gh ai pr chat 42" ]]
}

@test "_split_on_separator: handles empty before when -- is first arg" {
	local args=() cmd=()
	_split_on_separator args cmd -- gh ai pr chat 42

	[[ "${#args[@]}" -eq 0 ]]
	[[ "${cmd[*]}" == "gh ai pr chat 42" ]]
}

@test "_split_on_separator: returns two empty arrays for no arguments" {
	local args=() cmd=()
	_split_on_separator args cmd

	[[ "${#args[@]}" -eq 0 ]]
	[[ "${#cmd[@]}" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# _git_repo_path
# ---------------------------------------------------------------------------

@test "_git_repo_path: sets nameref when git rev-parse succeeds" {
	git() { echo "/repo/root"; }
	export -f git

	local path=""
	_git_repo_path path

	[[ "$path" == "/repo/root" ]]
}

@test "_git_repo_path: returns error when git rev-parse returns empty" {
	gum() { :; }
	export -f gum
	git() { echo ""; }
	export -f git

	local path=""
	run _git_repo_path path

	[[ "$status" -eq 1 ]]
}

# ---------------------------------------------------------------------------
# _gh_worktree_is_dirty
# ---------------------------------------------------------------------------

@test "_gh_worktree_is_dirty: returns 1 for clean worktree" {
	run _gh_worktree_is_dirty "$WORKTREE_PATH"
	[[ "$status" -eq 1 ]]
}

@test "_gh_worktree_is_dirty: returns 0 for untracked file" {
	echo "new" >"$WORKTREE_PATH/untracked.txt"

	run _gh_worktree_is_dirty "$WORKTREE_PATH"
	[[ "$status" -eq 0 ]]
}

@test "_gh_worktree_is_dirty: returns 0 for staged changes" {
	echo "staged" >"$WORKTREE_PATH/staged.txt"
	git -C "$WORKTREE_PATH" add staged.txt

	run _gh_worktree_is_dirty "$WORKTREE_PATH"
	[[ "$status" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# _gh_worktree_has_unpushed
# ---------------------------------------------------------------------------

@test "_gh_worktree_has_unpushed: returns 1 when up to date" {
	run _gh_worktree_has_unpushed "$WORKTREE_PATH"
	[[ "$status" -eq 1 ]]
}

@test "_gh_worktree_has_unpushed: returns 0 when commits ahead" {
	git -C "$WORKTREE_PATH" commit --allow-empty -m "local only" >/dev/null 2>&1

	run _gh_worktree_has_unpushed "$WORKTREE_PATH"
	[[ "$status" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# _gh_worktree_remove
# ---------------------------------------------------------------------------

@test "_gh_worktree_remove: removes clean worktree silently" {
	_gh_worktree_remove "$WORKTREE_PATH"

	[[ ! -d "$WORKTREE_PATH" ]]
}

@test "_gh_worktree_remove: succeeds when worktree path does not exist" {
	_gh_worktree_remove "/nonexistent/path"
}

@test "_gh_worktree_remove: auto-stashes uncommitted changes before removal" {
	echo "save me" >"$WORKTREE_PATH/dirty.txt"

	_gh_worktree_remove "$WORKTREE_PATH"

	[[ ! -d "$WORKTREE_PATH" ]]

	local stash_list
	stash_list=$(git -C "$BATS_TEST_TMPDIR/repo" stash list)
	[[ "$stash_list" == *"gh-worktree: auto-stash worktree 'issue-1'"* ]]
}

@test "_gh_worktree_remove: stash includes untracked files" {
	echo "untracked" >"$WORKTREE_PATH/new_file.txt"

	_gh_worktree_remove "$WORKTREE_PATH"

	git -C "$BATS_TEST_TMPDIR/repo" stash pop >/dev/null 2>&1
	[[ -f "$BATS_TEST_TMPDIR/repo/new_file.txt" ]]
}

@test "_gh_worktree_remove: warns about unpushed commits" {
	git -C "$WORKTREE_PATH" commit --allow-empty -m "unpushed work" >/dev/null 2>&1

	local output
	output=$(_gh_worktree_remove "$WORKTREE_PATH" 2>&1)

	[[ ! -d "$WORKTREE_PATH" ]]
	[[ "$output" == *"unpushed commits"* ]]
}

@test "_gh_worktree_remove: stashes and warns when both dirty and unpushed" {
	echo "dirty" >"$WORKTREE_PATH/dirty.txt"
	git -C "$WORKTREE_PATH" commit --allow-empty -m "unpushed" >/dev/null 2>&1

	local output
	output=$(_gh_worktree_remove "$WORKTREE_PATH" 2>&1)

	[[ ! -d "$WORKTREE_PATH" ]]
	[[ "$output" == *"auto-stash"*"issue-1"* ]]
	[[ "$output" == *"unpushed commits"* ]]
}

@test "_gh_worktree_remove: does not stash when worktree is clean" {
	_gh_worktree_remove "$WORKTREE_PATH"

	local stash_list
	stash_list=$(git -C "$BATS_TEST_TMPDIR/repo" stash list)
	[[ -z "$stash_list" ]]
}

# ---------------------------------------------------------------------------
# _gh_worktree_create
# ---------------------------------------------------------------------------

@test "_gh_worktree_create: creates worktree at expected path and prints it" {
	local repo_real
	repo_real=$(cd "$BATS_TEST_TMPDIR/repo" && pwd -P)
	local expected_path="$repo_real/.github/worktrees/pull-99"

	gh() { return 1; }
	export -f gh

	local output
	output=$(_gh_worktree_create "$repo_real" "pull-99" "$DEFAULT_BRANCH" "" "")

	[[ -d "$expected_path" ]]
	[[ "$output" == "$expected_path" ]]
}

@test "_gh_worktree_create: is idempotent when worktree already exists" {
	local repo_real
	repo_real=$(cd "$BATS_TEST_TMPDIR/repo" && pwd -P)

	gh() { return 1; }
	export -f gh

	_gh_worktree_create "$repo_real" "pull-100" "$DEFAULT_BRANCH" "" "" >/dev/null

	local output
	output=$(_gh_worktree_create "$repo_real" "pull-100" "$DEFAULT_BRANCH" "" "")

	[[ "$output" == "$repo_real/.github/worktrees/pull-100" ]]
}

@test "_gh_worktree_create: errors when branch is already checked out in another worktree" {
	local repo_real
	repo_real=$(cd "$BATS_TEST_TMPDIR/repo" && pwd -P)

	gh() { return 1; }
	export -f gh

	# issue-1 is already checked out in WORKTREE_PATH from setup
	run _gh_worktree_create "$repo_real" "issue-1-alt" "$DEFAULT_BRANCH" "" "issue-1"

	[[ "$status" -ne 0 ]]
	[[ "$output" == *"already checked out"* ]]
}

@test "_gh_worktree_create: uses GH_WORKTREE_DIR when set" {
	local repo_real
	repo_real=$(cd "$BATS_TEST_TMPDIR/repo" && pwd -P)
	export GH_WORKTREE_DIR="$BATS_TEST_TMPDIR/custom-worktrees"

	gh() { return 1; }
	export -f gh

	local output
	output=$(_gh_worktree_create "$repo_real" "pull-101" "$DEFAULT_BRANCH" "" "")

	[[ "$output" == "$BATS_TEST_TMPDIR/custom-worktrees/pull-101" ]]
	[[ -d "$BATS_TEST_TMPDIR/custom-worktrees/pull-101" ]]
	unset GH_WORKTREE_DIR
}

# ---------------------------------------------------------------------------
# _gh_worktree_run
# ---------------------------------------------------------------------------

@test "_gh_worktree_run: changes into the worktree directory and runs command" {
	run _gh_worktree_run "$WORKTREE_PATH" pwd

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"issue-1"* ]]
}

@test "_gh_worktree_run: passes command arguments correctly" {
	run _gh_worktree_run "$WORKTREE_PATH" echo "hello world"

	[[ "$status" -eq 0 ]]
	[[ "$output" == *"hello world"* ]]
}

@test "_gh_worktree_run: removes worktree on exit" {
	run _gh_worktree_run "$WORKTREE_PATH" true

	[[ ! -d "$WORKTREE_PATH" ]]
}

@test "_gh_worktree_run: forwards command exit status" {
	run _gh_worktree_run "$WORKTREE_PATH" false

	[[ "$status" -ne 0 ]]
}
