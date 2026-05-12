# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi


### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

# Load syntax highlighting (colors your commands as you type)
zinit light zdharma-continuum/fast-syntax-highlighting

# Load autosuggestions (suggests commands based on history)
zinit light zsh-users/zsh-autosuggestions

# Load completions (better tab-completion for tools like git, docker, etc.)
zinit light zsh-users/zsh-completions

### End of Zinit's installer chunk

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

zinit ice depth=1; zinit light romkatv/powerlevel10k

git-protocol() {
  if [[ $1 == "ssh" ]]; then
    git config --global --unset url."https://github.com/".insteadOf 2>/dev/null
    git config --global url."git@github.com:".insteadOf "https://github.com/"
    echo "GitHub protocol switched to SSH"

  elif [[ $1 == "https" ]]; then
    git config --global --unset url."git@github.com:".insteadOf 2>/dev/null
    git config --global url."https://github.com/".insteadOf "git@github.com:"
    echo "GitHub protocol switched to HTTPS"

  else
    echo "Usage: git-protocol [ssh|https]"
  fi
}
