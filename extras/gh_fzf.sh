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

_gh_fzf_tmux_use=0
if [[ -n "${TMUX:-}" ]]; then
	_gh_fzf_tmux_session=$(tmux display-message -p '#S')
	_gh_fzf_tmux_cmd="$_gh_fzf_dir/gh_tmux_cmd.sh"
	_gh_fzf_tmux_use=1
fi

if [[ "$_gh_fzf_tmux_use" -eq 1 ]]; then
	_gh_fzf_pr_opts=(
		"--bind=alt-W:execute-silent(${_gh_fzf_tmux_cmd} new-window worktrees/pull-{1} gh worktree pr {1})+abort"
		"--bind=alt-S:execute-silent(gh worktree pr {1} --keep -- ${_gh_fzf_tmux_cmd} new-session ${_gh_fzf_tmux_session}/pull-{1})+abort"
	)
else
	_gh_fzf_pr_opts=("--bind=alt-W:execute(gh worktree pr {1})+abort")
fi
GH_FZF_PR_OPTS+="${GH_FZF_PR_OPTS:+ }$(printf '%q ' "${_gh_fzf_pr_opts[@]}")"
GH_FZF_PR_OPTS="${GH_FZF_PR_OPTS% }"
export GH_FZF_PR_OPTS
unset _gh_fzf_pr_opts

if [[ "$_gh_fzf_tmux_use" -eq 1 ]]; then
	_gh_fzf_issue_opts=(
		"--bind=alt-W:execute-silent(${_gh_fzf_tmux_cmd} new-window worktrees/issue-{1} gh worktree issue {1})+abort"
		"--bind=alt-S:execute-silent(gh worktree issue {1} --keep -- ${_gh_fzf_tmux_cmd} new-session ${_gh_fzf_tmux_session}/issue-{1})+abort"
	)
else
	_gh_fzf_issue_opts=("--bind=alt-W:execute(gh worktree issue {1})+abort")
fi
GH_FZF_ISSUE_OPTS+="${GH_FZF_ISSUE_OPTS:+ }$(printf '%q ' "${_gh_fzf_issue_opts[@]}")"
GH_FZF_ISSUE_OPTS="${GH_FZF_ISSUE_OPTS% }"
export GH_FZF_ISSUE_OPTS
unset _gh_fzf_issue_opts

if [[ "$_gh_fzf_tmux_use" -eq 1 ]]; then
	_gh_fzf_run_opts=(
		"--bind=alt-W:execute-silent(${_gh_fzf_tmux_cmd} new-window worktrees/run-{-1} gh worktree run {-1})+abort"
		"--bind=alt-S:execute-silent(gh worktree run {-1} --keep -- ${_gh_fzf_tmux_cmd} new-session ${_gh_fzf_tmux_session}/run-{-1})+abort"
	)
else
	_gh_fzf_run_opts=("--bind=alt-W:execute(gh worktree run {-1})+abort")
fi
GH_FZF_RUN_OPTS+="${GH_FZF_RUN_OPTS:+ }$(printf '%q ' "${_gh_fzf_run_opts[@]}")"
GH_FZF_RUN_OPTS="${GH_FZF_RUN_OPTS% }"
export GH_FZF_RUN_OPTS
unset _gh_fzf_run_opts _gh_fzf_tmux_use _gh_fzf_tmux_session _gh_fzf_tmux_cmd _gh_fzf_dir
