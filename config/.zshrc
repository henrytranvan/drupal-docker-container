# Configuration file for ZSH

# Add composer binaries to path
export PATH="$HOME/.composer/vendor/bin:$PATH"

#Load defaut config 
source $HOME/.bash_profile

# Disable composer warning about xdebug presence
export COMPOSER_DISABLE_XDEBUG_WARN=1

# Add settings for drupal console
source "$HOME/.console/console.rc" 2>/dev/null

# Configuration for oh-my-zsh
export ZSH_THEME=essembeh
export ZSH="$HOME/.oh-my-zsh"
source $ZSH/oh-my-zsh.sh

