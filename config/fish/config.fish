if status is-interactive

    starship init fish | source

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
alias update='sudo pacman -Syu; sudo pacman -Sy'
alias aurupdate='yay -Syu'
alias cc='cliphist wipe'
alias hc='history clear'
alias ff='clear && echo; cat ~/.config/fastfetch/text.txt && fastfetch --logo none'
alias f='fetch'
alias fs='clear && fastfetch -c examples/3.jsonc'
alias spotatui='spotatui -U'
alias cc='qs ipc call dashboard toggle'
alias wallpaper='qs ipc call wallpaper toggle'
alias bar='qs ipc call bar toggleStyle'
alias ww='clear && fastfetch'


end
