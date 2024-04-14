#!/bin/sh

SHELL_PATH=/opt/homebrew/bin/zsh

echo "Setting shell to $SHELL_PATH"
sudo dscl . -create /Users/$USER UserShell $SHELL_PATH
