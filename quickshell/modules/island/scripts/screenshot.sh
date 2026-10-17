#!/bin/sh
mode="$1"
monitor="$2"
ws="$3"
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png"

case "$mode" in
region)
    geo=$(slurp) || exit 1
    grim -g "$geo" "$file" || exit 2
    ;;
window)
    geo=$(hyprctl -j clients | jq -r --argjson ws "${ws:-0}" '.[] | select(.mapped and (.hidden | not) and .workspace.id == $ws) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' | slurp -r) || exit 1
    grim -g "$geo" "$file" || exit 2
    ;;
*)
    if [ -n "$monitor" ]; then
        grim -o "$monitor" "$file" || exit 2
    else
        grim "$file" || exit 2
    fi
    ;;
esac

wl-copy < "$file"
