# p10k prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# zinit
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# annexes
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

# plugins
zinit light zdharma-continuum/fast-syntax-highlighting
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-completions

# theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
zinit ice depth=1; zinit light romkatv/powerlevel10k

# editor
export EDITOR="nvim"
export VISUAL="nvim"

# functions
git-protocol() {
  if [[ $1 == "ssh" ]]; then
    git config --global --unset url."https://github.com/".insteadOf 2>/dev/null
    git config --global url."git@github.com:".insteadOf "https://github.com/"
    echo "SSH"
  elif [[ $1 == "https" ]]; then
    git config --global --unset url."git@github.com:".insteadOf 2>/dev/null
    git config --global url."https://github.com/".insteadOf "git@github.com:"
    echo "HTTPS"
  else
    echo "usage: git-protocol [ssh|https]"
  fi
}
