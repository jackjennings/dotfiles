setopt prompt_subst

_git_worktree_indicator() {
  local git_dir common_dir
  git_dir="$(git rev-parse --git-dir 2>/dev/null)" || return
  common_dir="$(git rev-parse --git-common-dir 2>/dev/null)" || return
  [[ "$git_dir" != "$common_dir" ]] && echo ' (wt)'
}

PROMPT='%B%F{7}%1~%f%b ⎬ '
RPROMPT='%B%F{7}$(git_current_branch)$(_git_worktree_indicator)%f%b'
PROMPT_EOL_MARK='%B%F{7}↵%f%b'
