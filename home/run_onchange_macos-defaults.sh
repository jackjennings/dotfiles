#!/bin/sh

defaults write "Apple Global Domain" AppleInterfaceStyle Dark

# Dock

## Hide dock by default
defaults write com.apple.dock "autohide" -bool "true"

## Hide recent files
defaults write com.apple.dock "show-recents" -bool "false"

## Only show active applications in dock
defaults write com.apple.dock "static-only" -bool "true"

killall Dock

# Safari

## Show full URL 
defaults write com.apple.Safari "ShowFullURLInSmartSearchField" -bool "true" && killall Safari

# Finder

## Show all file extensions
defaults write NSGlobalDomain "AppleShowAllExtensions" -bool "true"

## Disable file extension change warning
defaults write com.apple.finder "FXEnableExtensionChangeWarning" -bool "false"

killall Finder

# Menu bar

## Set time format

defaults write com.apple.menuextra.clock "DateFormat" -string "\"MMM d HH:mm\""

# TextEdit

## Use plain text by default
defaults write com.apple.TextEdit "RichText" -bool "false"

