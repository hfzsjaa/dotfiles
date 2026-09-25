#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

eval "$(starship init bash)"   

cat ~/.cache/wal/sequences

alias asd='notify-send eh-blunder-lagi'
alias easteregg='notify-send OTP: P71450L0'
alias ls='ls -la  --color=auto'
alias grep='grep --color=auto'
alias get='sudo pacman -S'
alias aurget='yay -S'
alias del='sudo pacman -Rsn'
alias aurdel='yay -Rsn'
alias reboot='sudo reboot now'
alias off='sudo shutdown now'
alias fetch='fetch -l windows'
alias update='sudo pacman -Syu; sudo pacman -Sy'
alias aurupdate='yay -Syu'
alias cc='cliphist wipe'
alias hc='history -c'
alias ff='clear && fastfetch'
alias f='fetch'
alias fs='ff -c examples/3.jsonc'

PS1='[\u@\h \W]\$ '
