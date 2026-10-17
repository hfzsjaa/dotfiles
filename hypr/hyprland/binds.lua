local terminal    = "foot"
local fileManager = "thunar"
local browser     = "firefox"
local editor      = "codium"
local reload      = "~/.config/hypr/scripts/reload.sh"
local picker      = "hyprpicker -a"
local step        = 40

local mainMod     = "SUPER"

--      QUICKSHELL
local menu        = "qs ipc call launcher toggle"

local dashboard   = "qs ipc call dashboard toggle"
local clipboard   = "qs ipc call clipboard toggle"
local wallpaper   = "qs ipc call wallpaper toggle"
local overview    = "qs ipc call overview toggle"
local bar         = "qs ipc call bar toggleStyle"
local powermenu   = "qs ipc call powermenu toggle"
local lock        = "qs ipc call lockscreen lock"
local notif       = "qs ipc call notifications toggle"
local dnd         = "qs ipc call notifications toggleDnd"

hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd(clipboard))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd(wallpaper))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd(powermenu))
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.exec_cmd(bar))
hl.bind("ALT + TAB", hl.dsp.exec_cmd(overview))
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + SHIFT + TAB", hl.dsp.exec_cmd(dashboard))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(lock))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(notif))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd(dnd))

--      QUICKSHELL


hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(editor))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(reload))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(picker))


hl.bind(mainMod .. " + A", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + D", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + W", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + S", hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + CTRL + left", hl.dsp.window.resize({ x = -step, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = step, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + up", hl.dsp.window.resize({ x = 0, y = -step, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + down", hl.dsp.window.resize({ x = 0, y = step, relative = true }), { repeating = true })

hl.bind(mainMod .. " + ALT + left", hl.dsp.window.move({ x = -step, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + ALT + right", hl.dsp.window.move({ x = step, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + ALT + up", hl.dsp.window.move({ x = 0, y = -step, relative = true }), { repeating = true })
hl.bind(mainMod .. " + ALT + down", hl.dsp.window.move({ x = 0, y = step, relative = true }), { repeating = true })

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + M",
  hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))

local closeWindowBind = hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))


hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("F9", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("F8", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("F10", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
  { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
