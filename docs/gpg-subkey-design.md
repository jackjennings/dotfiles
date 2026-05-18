# GPG Subkey Design

## Problem

The current `gpg-setup-key` script generates a brand new GPG key on every machine. Each machine has a different key fingerprint, requiring separate GitHub registrations and presenting an inconsistent signing identity across devices.

## Approach

One master key represents the identity. Each machine gets a unique signing subkey derived from it. The master key lives only in 1Password and is never stored on disk. Per-machine subkeys are protected by device-specific passphrases, also stored in 1Password, keyed by hardware UUID.

```
1Password
├── GPG Master Key             ← ASCII-armored private master key (cert-only)
├── GPG Master Key Passphrase  ← passphrase protecting the master key
└── GPG Subkey <UUID>          ← per-device subkey passphrase (created on first run)

~/.gnupg (each machine)
└── secret subkeys only        ← master fingerprint never present after setup
```

## 1Password Item Structure

| Title | Vault | Category | Field | Notes |
|-------|-------|----------|-------|-------|
| `GPG Master Key` | Personal | Document | — | ASCII-armored `--export-secret-keys` output |
| `GPG Master Key Passphrase` | Personal | Password | `password` | Protects the master key |
| `GPG Subkey <UUID>` | Personal | Password | `password` | Created automatically on first run per device |

Hardware UUID is obtained via:
```sh
system_profiler SPHardwareDataType | awk '/Hardware UUID/ { print $3 }'
```

## First-Run Flow

```
gpg-setup-key runs
│
├─ key already exists locally? → skip (existing run_onchange_ behaviour)
│
├─ fetch master key from 1Password
│   op document get "GPG Master Key" --account $OP_ACCOUNT
│
├─ import master into temp GNUPGHOME
│   GNUPGHOME=$(mktemp -d)
│   gpg --batch --pinentry-mode loopback --passphrase "$MASTER_PASS" --import
│
├─ generate signing subkey
│   gpg --batch --pinentry-mode loopback --passphrase "$MASTER_PASS" \
│       --quick-add-key "$MASTER_FP" rsa4096 sign 0
│
├─ generate device passphrase + store in 1Password
│   DEVICE_PASS=$(openssl rand -base64 32)
│   op item create --vault personal --title "GPG Subkey $UUID" \
│       --category Password password="$DEVICE_PASS"
│
├─ re-encrypt local keychain with device passphrase
│   gpg --batch --pinentry-mode loopback \
│       --passphrase-fd 0 --command-fd 0 --edit-key "$MASTER_FP"
│   (input: master pass → new pass → new pass → save)
│
├─ export subkeys only (now protected by device passphrase)
│   gpg --batch --pinentry-mode loopback --passphrase "$DEVICE_PASS" \
│       --export-secret-subkeys --armor "$MASTER_FP"
│
├─ wipe temp GNUPGHOME, import subkeys into real ~/.gnupg
│   rm -rf "$GNUPGHOME"
│   gpg --batch --pinentry-mode loopback --passphrase "$DEVICE_PASS" --import
│
└─ register public key with GitHub (same as current script)
```

The master key is never written to `~/.gnupg`. It exists only in `$GNUPGHOME` which is a `mktemp -d` directory wiped before the function returns.

## Subsequent Runs

`run_onchange_setup-gpg.sh.tmpl` re-runs when its rendered content changes. The script checks for an existing secret key for `$EMAIL` at the top and exits early — same as today.

## Pinentry Script Changes

`pinentry-1password.sh` currently reads a fixed item name. It needs to resolve the device UUID at startup and look up the per-device item:

```sh
DEVICE_UUID=$(system_profiler SPHardwareDataType | awk '/Hardware UUID/ { print $3 }')
OP_PGP_PASSPHRASE_ITEM="op://Personal/GPG Subkey ${DEVICE_UUID}/password"
```

Everything else in the pinentry script stays the same. The `OP_ACCOUNT` variable and retry logic are unchanged.

## Scripts

Three scripts live in `~/.local/bin` (chezmoi: `dot_local/bin/`):

| Script | Purpose | When to run |
|--------|---------|-------------|
| `gpg-master-key` | One-time master key creation | Before setting up any machine |
| `gpg-setup-key` | Per-machine subkey setup | Automatically via `run_onchange_` |
| `gpg-revoke` | Decommission a machine's subkey | When retiring a device |

---

### `gpg-master-key` (new)

Run once, ever. Creates the master key, stores it and its passphrase in 1Password, and generates a revocation certificate. Errors if `GPG Master Key` already exists in 1Password.

```sh
#!/bin/bash
set -e

OP_ACCOUNT="{{ .onepassword.account_id }}"
EMAIL="${1:?Usage: gpg-master-key <email>}"
NAME=$(git config --global --includes user.name)

# ensure not already set up
if op document get "GPG Master Key" --account "$OP_ACCOUNT" &>/dev/null; then
  echo "GPG Master Key already exists in 1Password. Aborting." >&2
  exit 1
fi

# generate passphrase + master key
MASTER_PASS=$(openssl rand -base64 32)

GNUPGHOME=$(mktemp -d)
trap "rm -rf '$GNUPGHOME'" EXIT
export GNUPGHOME

gpg --batch --generate-key <<EOF
Key-Type: RSA
Key-Length: 4096
Key-Usage: cert
Name-Real: $NAME
Name-Email: $EMAIL
Passphrase: $MASTER_PASS
Expire-Date: 0
EOF

# store in 1Password
gpg --armor --export-secret-keys "$EMAIL" \
  | op document create - --vault personal --title "GPG Master Key" \
      --account "$OP_ACCOUNT"

op item create --vault personal --title "GPG Master Key Passphrase" \
    --category Password password="$MASTER_PASS" \
    --account "$OP_ACCOUNT"

# store revocation certificate
gpg --batch --yes --pinentry-mode loopback --passphrase "$MASTER_PASS" \
    --gen-revoke "$EMAIL" \
  | op document create - --vault personal --title "GPG Master Key Revocation" \
      --account "$OP_ACCOUNT"

echo "Master key created and stored in 1Password." >&2
echo "Run gpg-setup-key to provision this machine." >&2
```

---

### `gpg-setup-key` (updated)

The existing script's structure is preserved. Changes:

1. Add `DEVICE_UUID` and `OP_ACCOUNT` variables at top
2. Replace the `gpg --batch --generate-key` block with a check for `GPG Master Key` in 1Password, then the subkey flow
3. Error clearly if `GPG Master Key` is missing (directing the user to run `gpg-master-key` first)
4. The GitHub registration block at the bottom is unchanged

---

### `gpg-revoke` (new)

Revokes a specific machine's subkey by UUID. Accepts the UUID as an argument (defaults to the current machine). Updates the master key document in 1Password and re-registers the public key with GitHub.

```sh
#!/bin/bash
set -e

OP_ACCOUNT="{{ .onepassword.account_id }}"
TARGET_UUID="${1:-$(system_profiler SPHardwareDataType | awk '/Hardware UUID/ { print $3 }')}"

MASTER_PASS=$(op read "op://Personal/GPG Master Key Passphrase/password" \
    --account "$OP_ACCOUNT")

GNUPGHOME=$(mktemp -d)
trap "rm -rf '$GNUPGHOME'" EXIT
export GNUPGHOME

op document get "GPG Master Key" --account "$OP_ACCOUNT" \
  | gpg --batch --pinentry-mode loopback --passphrase "$MASTER_PASS" --import

MASTER_FP=$(gpg --list-secret-keys --with-colons \
  | awk -F: '$1 == "sec" { print $5 }' | head -1)

# find subkey by matching creation date stored in 1Password item notes,
# or interactively prompt to select
echo "Select the subkey to revoke for device $TARGET_UUID" >&2
gpg --edit-key "$MASTER_FP"
# operator: key N → revkey → save

# update master key document with revoked subkey
gpg --armor --export-secret-keys "$MASTER_FP" \
  | op document edit "GPG Master Key" - --account "$OP_ACCOUNT"

# push updated public key to GitHub
gpg --armor --export "$MASTER_FP" | gh gpg-key add -

# clean up device passphrase
op item delete "GPG Subkey $TARGET_UUID" --account "$OP_ACCOUNT"

echo "Subkey for $TARGET_UUID revoked." >&2
```

Note: the `gpg --edit-key` step in `gpg-revoke` is intentionally interactive. Automating subkey selection by UUID requires storing the subkey fingerprint at creation time — a possible future improvement.

## Migration from Current Setup

Existing machines keep their current keys indefinitely — no forced migration. New machines get the subkey flow automatically once the `GPG Master Key` document is present in 1Password.

For existing machines, re-running `gpg-setup-key` manually after deleting the local key will trigger the subkey flow. This is optional.
