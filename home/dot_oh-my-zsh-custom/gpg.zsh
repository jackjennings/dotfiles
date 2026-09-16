# This is required for pinentry to display the password dialog correctly
# See: https://unix.stackexchange.com/questions/257061/gentoo-linux-gpg-encrypts-properly-a-file-passed-through-parameter-but-throws-i/257065#257065
export GPG_TTY=$(tty)

# Warns once per day when the 1Password service-account token consumed by
# pinentry-1password.sh is close to expiring. Silent no-op until
# op-service-account-setup has run at least once.
_op_service_account_expiry_file=~/.cache/op-service-account-expiry
_op_service_account_warn_days=14

if [[ -f "$_op_service_account_expiry_file" ]]; then
  _op_service_account_warned_file=~/.cache/op-service-account-last-warned
  _op_service_account_today=$(date +%Y-%m-%d)

  if [[ ! -f "$_op_service_account_warned_file" ]] \
      || [[ "$(cat "$_op_service_account_warned_file" 2>/dev/null)" != "$_op_service_account_today" ]]; then
    _op_service_account_expiry=$(cat "$_op_service_account_expiry_file")
    _op_service_account_expiry_epoch=$(date -j -f "%Y-%m-%d" "$_op_service_account_expiry" +%s 2>/dev/null)
    _op_service_account_today_epoch=$(date -j -f "%Y-%m-%d" "$_op_service_account_today" +%s 2>/dev/null)

    if [[ -n "$_op_service_account_expiry_epoch" && -n "$_op_service_account_today_epoch" ]]; then
      _op_service_account_days_left=$(( (_op_service_account_expiry_epoch - _op_service_account_today_epoch) / 86400 ))

      if (( _op_service_account_days_left <= _op_service_account_warn_days )); then
        echo "⚠ 1Password pinentry service-account token expires $_op_service_account_expiry — run 'op-service-account-setup' to rotate it." >&2
      fi
      echo "$_op_service_account_today" > "$_op_service_account_warned_file"
    fi

    unset _op_service_account_expiry _op_service_account_expiry_epoch \
      _op_service_account_today_epoch _op_service_account_days_left
  fi

  unset _op_service_account_warned_file _op_service_account_today
fi

unset _op_service_account_expiry_file _op_service_account_warn_days
