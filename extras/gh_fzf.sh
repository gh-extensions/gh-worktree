# gh-worktree fzf bindings — source this file in your shell config to register
# all gh-worktree keybinds with gh-fzf via GH_FZF_*_OPTS.
#
# Usage: add to ~/.bashrc or ~/.zshrc
#   source /path/to/extras/gh_fzf.sh
#
# Keybinds added (only when inside tmux):
#
#   gh-fzf pr
#     alt-S   Open a new tmux session with a worktree for the selected PR
#
#   gh-fzf issue
#     alt-S   Open a new tmux session with a worktree for the selected issue
#
#   gh-fzf run
#     alt-S   Open a new tmux session with a worktree for the selected run

if [[ -z "${TMUX:-}" ]]; then
	return 0
fi

_gh_fzf_pr_opts=(
	'--bind "alt-S:execute(tmux new-session -s pull-{1} gh worktree pr {1})"'
)
export GH_FZF_PR_OPTS="${GH_FZF_PR_OPTS:+${GH_FZF_PR_OPTS} }${_gh_fzf_pr_opts[*]}"
unset _gh_fzf_pr_opts

_gh_fzf_issue_opts=(
	'--bind "alt-S:execute(tmux new-session -s issue-{1} gh worktree issue {1})"'
)
export GH_FZF_ISSUE_OPTS="${GH_FZF_ISSUE_OPTS:+${GH_FZF_ISSUE_OPTS} }${_gh_fzf_issue_opts[*]}"
unset _gh_fzf_issue_opts

_gh_fzf_run_opts=(
	'--bind "alt-S:execute(tmux new-session -s run-{-1} gh worktree run {-1})"'
)
export GH_FZF_RUN_OPTS="${GH_FZF_RUN_OPTS:+${GH_FZF_RUN_OPTS} }${_gh_fzf_run_opts[*]}"
unset _gh_fzf_run_opts
