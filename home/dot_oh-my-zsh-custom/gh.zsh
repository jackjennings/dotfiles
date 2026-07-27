export GH_NO_UPDATE_NOTIFIER=1

gh() {
  if [[ "$1" == "auth" ]]; then
    command gh "$@"
    return
  fi

  local account token
  account="$(~/.config/git/bin/gh-account-for-pwd)"
  token="$(command gh auth token --user "$account" 2>&1)" || {
    echo "gh: failed to get token for account '$account': $token" >&2
    return 1
  }
  GH_TOKEN="$token" command gh "$@"
}
