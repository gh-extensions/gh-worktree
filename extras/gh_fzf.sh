# gh-worktree fzf bindings — source this file in your shell config to register
# all gh-worktree keybinds with gh-fzf via GH_FZF_*_OPTS.
#
# Usage: add to ~/.bashrc or ~/.zshrc
#   source /path/to/extras/gh_fzf.sh
#
# Keybinds added:
#
#   gh-fzf pr
#     alt-W   Open a worktree for the selected PR (new tmux window or inline)
#     alt-S   Open a worktree for the selected PR in a new tmux session (tmux only)
#
#   gh-fzf issue
#     alt-W   Open a worktree for the selected issue (new tmux window or inline)
#     alt-S   Open a worktree for the selected issue in a new tmux session (tmux only)
#
#   gh-fzf run
#     alt-W   Open a worktree for the selected run (new tmux window or inline)
#     alt-S   Open a worktree for the selected run in a new tmux session (tmux only)

_gh_fzf_dir=$(dirname "${BASH_SOURCE[0]:-$0}")
[[ "$_gh_fzf_dir" = /* ]] || _gh_fzf_dir="$(cd "$_gh_fzf_dir" && pwd)"

_gh_fzf_tmux="$_gh_fzf_dir/gh_tmux.sh"

_gh_fzf_use_tmux=0
if [[ -n "${TMUX:-}" ]]; then
	_gh_fzf_session=$(tmux display-message -p '#S')
	_gh_fzf_use_tmux=1
fi

if [[ "$_gh_fzf_use_tmux" -eq 1 ]]; then
	_gh_fzf_pr_opts=(
		--bind "alt-W:execute-silent(${_gh_fzf_tmux} new-window worktrees/pull-{1} gh worktree pr {1})"
		--bind "alt-S:execute(gh worktree pr {1} --keep -- ${_gh_fzf_tmux} new-session ${_gh_fzf_session}/pull-{1})"
	)
else
	_gh_fzf_pr_opts=(--bind "alt-W:execute(gh worktree pr {1})")
fi
export GH_FZF_PR_OPTS="${GH_FZF_PR_OPTS:+${GH_FZF_PR_OPTS} }${_gh_fzf_pr_opts[*]}"
unset _gh_fzf_pr_opts

if [[ "$_gh_fzf_use_tmux" -eq 1 ]]; then
	_gh_fzf_issue_opts=(
		--bind "alt-W:execute-silent(${_gh_fzf_tmux} new-window worktrees/issue-{1} gh worktree issue {1})"
		--bind "alt-S:execute(gh worktree issue {1} --keep -- ${_gh_fzf_tmux} new-session ${_gh_fzf_session}/issue-{1})"
	)
else
	_gh_fzf_issue_opts=(--bind "alt-W:execute(gh worktree issue {1})")
fi
export GH_FZF_ISSUE_OPTS="${GH_FZF_ISSUE_OPTS:+${GH_FZF_ISSUE_OPTS} }${_gh_fzf_issue_opts[*]}"
unset _gh_fzf_issue_opts

if [[ "$_gh_fzf_use_tmux" -eq 1 ]]; then
	_gh_fzf_run_opts=(
		--bind "alt-W:execute-silent(${_gh_fzf_tmux} new-window worktrees/run-{-1} gh worktree run {-1})"
		--bind "alt-S:execute(gh worktree run {-1} --keep -- ${_gh_fzf_tmux} new-session ${_gh_fzf_session}/run-{-1})"
	)
else
	_gh_fzf_run_opts=(--bind "alt-W:execute(gh worktree run {-1})")
fi
export GH_FZF_RUN_OPTS="${GH_FZF_RUN_OPTS:+${GH_FZF_RUN_OPTS} }${_gh_fzf_run_opts[*]}"
unset _gh_fzf_run_opts _gh_fzf_use_tmux _gh_fzf_session _gh_fzf_tmux _gh_fzf_dir
