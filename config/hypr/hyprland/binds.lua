local terminal    = "kitty"
local fileManager = "kitty yazi"
local browser     = "brave-origin-nightly"
local editor      = "codium"
local reload      = "~/.config/hypr/scripts/reload.sh"
local screenshot  = "hyprshot -m output -o Pictures/screenshots"
local record      = "~/.config/hypr/scripts/record.sh"
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

hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd(clipboard))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd(wallpaper))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd(powermenu))
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.exec_cmd(bar))
hl.bind("ALT + TAB", hl.dsp.exec_cmd(overview))
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + SHIFT + TAB", hl.dsp.exec_cmd(dashboard))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(lock))

--      QUICKSHELL


hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(editor))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(reload))
hl.bind("Print", hl.dsp.exec_cmd(screenshot))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd(record))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(picker))


hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

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

local layoutFile = os.getenv("HOME") .. "/.cache/hypr-layout"

local function saveLayout(name)
  local f = io.open(layoutFile, "w")
  if f then
    f:write(name)
    f:close()
  end
end

local function toggleLayout()
  local nextLayout = (hl.get_config("general.layout") == "scrolling") and "dwindle" or "scrolling"
  hl.config({ general = { layout = nextLayout } })
  saveLayout(nextLayout)
end

hl.bind(mainMod .. " + SPACE", toggleLayout)

local function layoutBind(keys, scrolling, dwindle)
  hl.bind(keys, function()
    local current = hl.get_config("general.layout")
    hl.dispatch(current == "dwindle" and dwindle or scrolling)
  end)
end

layoutBind(mainMod .. " + W",
  hl.dsp.layout("colresize +0.05"),
  hl.dsp.layout("splitratio +0.05"))

layoutBind(mainMod .. " + S",
  hl.dsp.layout("colresize -0.05"),
  hl.dsp.layout("splitratio -0.05"))

layoutBind(mainMod .. " + A",
  hl.dsp.layout("move -col"),
  hl.dsp.window.move({ direction = "left" }))

layoutBind(mainMod .. " + D",
  hl.dsp.layout("move +col"),
  hl.dsp.window.move({ direction = "right" }))

layoutBind(mainMod .. " + SHIFT + A",
  hl.dsp.layout("swapcol l"),
  hl.dsp.window.swap({ direction = "left" }))

layoutBind(mainMod .. " + SHIFT + D",
  hl.dsp.layout("swapcol r"),
  hl.dsp.window.swap({ direction = "right" }))

layoutBind(mainMod .. " + F",
  hl.dsp.layout("fit active"),
  hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))

layoutBind(mainMod .. " + SHIFT + F",
  hl.dsp.layout("promote"),
  hl.dsp.layout("movetoroot"))

hl.bind(mainMod .. " + SHIFT + W", hl.dsp.window.swap({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.swap({ direction = "down" }))

for i = 1, 10 do
  local key = i % 10
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("F9", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("F8", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
  { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
