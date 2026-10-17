#!/bin/sh
mode="$1"
monitor="$2"
state="$HOME/.local/state/quickshell/recording"
dir="$HOME/Videos/Recordings"
mkdir -p "$dir" "$(dirname "$state")"
file="$dir/recording-$(date +%Y-%m-%d_%H-%M-%S).mp4"

if [ "$mode" = region ]; then
    geo=$(slurp) || exit 1
    set -- -g "$geo"
elif [ -n "$monitor" ]; then
    set -- -o "$monitor"
else
    set --
fi

wf-recorder "$@" -f "$file" >/dev/null 2>&1 &
pid=$!
sleep 0.6
if ! kill -0 "$pid" 2>/dev/null; then
    notify-send "Recording failed" "wf-recorder could not start"
    exit 2
fi

echo "$pid $(date +%s) $file" > "$state"
wait "$pid"
rm -f "$state"
