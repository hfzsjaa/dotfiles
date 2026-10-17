#!/bin/bash

pkill -x qs

qs &

hyprctl reload

pkill -USR2 cava
