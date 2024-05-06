#!/bin/sh

OP_PGP_PASSPHRASE_ITEM="op://Personal/PGP Passphrase/password"

echo "OK"
while read cmd rest; do
  case "$cmd" in
    \#*)
      echo "OK"
      ;;
    GETPIN)
      PASSPHRASE=$(op read "$OP_PGP_PASSPHRASE_ITEM")
      echo "D ${PASSPHRASE}"
      echo "OK"
      ;;
    BYE)
      echo "OK"
      exit 0
      ;;
    *)
      echo "OK"
      ;;
  esac
done
