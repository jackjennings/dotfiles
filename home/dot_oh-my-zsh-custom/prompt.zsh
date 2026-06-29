setopt prompt_subst

_git_worktree_indicator() {
  [[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" == "true" ]] && echo ' (wt)'
}

PROMPT='%B%F{7}%1~%f%b ⎬ '
RPROMPT='%B%F{7}$(git_current_branch)$(_git_worktree_indicator)%f%b'
PROMPT_EOL_MARK='%B%F{7}↵%f%b'
