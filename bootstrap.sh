if ! type "brew" > /dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

/opt/homebrew/bin/brew install chezmoi gh

if [ ! -f ~/.ssh/id_rsa ]; then
  ssh-keygen -f ~/.ssh/id_rsa
fi

/opt/homebrew/bin/gh auth login \
  --git-protocol ssh \
  --hostname github.com

/opt/homebrew/bin/chezmoi init --apply https://github.com/jackjennings/dotfiles.git
