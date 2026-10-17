#!/usr/bin/env bash
dir="$HOME/Videos/Recordings"
mkdir -p "$dir"

if pgrep -x wf-recorder >/dev/null; then
    pkill -INT -x wf-recorder
    notify-send "Recording" "Done saved in $dir"
else
    notify-send "Recording" "Start"
    sink="$(pactl get-default-sink).monitor"
    wf-recorder -r 30 -c libx264 -x yuv420p \
        -p preset=ultrafast -p crf=28 \
        --audio="$sink" \
        -f "$dir/rec-$(date +%F_%H-%M-%S).mp4"
fi