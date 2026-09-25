local colors = {}

local file = io.open(
    os.getenv("HOME") .. "/.cache/wal/colors-hyprland.conf",
    "r"
)

if file then
    for line in file:lines() do
        local name, value = line:match("^%$(color%d+)%s*=%s*(.+)$")

        if name and value then
            colors[name] = value
        end
    end

    file:close()
end

local foreground = colors.color7 or "rgba(ffffff,1.0)"
local background = colors.color0 or "rgba(111111,1.0)"

local accent1 = colors.color4 or foreground
local accent2 = colors.color5 or accent1
local inactive = colors.color9 or background

hl.config({
    general = {
        gaps_in = 0,
        gaps_out = 0,

        border_size = 1,

        col = {
            active_border = {
                colors = {
                    accent1,
                    accent2
                }
            },

            inactive_border = inactive,
        },

        resize_on_border = false,
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding = 0,
        rounding_power = 0,

        active_opacity = 1,
        inactive_opacity = 0.9,

        shadow = {
            enabled = false,
        },

        blur = {
            enabled = true,
            size = 2,
            passes = 3,
            vibrancy = 0,
        },
    },

    animations = {
        enabled = true,
    },
})

hl.curve("smooth",    { type = "bezier", points = { {0.22, 1.0}, {0.36, 1.0} } })
hl.curve("smoothOut", { type = "bezier", points = { {0.32, 0.0}, {0.67, 0.0} } })

hl.animation({ leaf = "global", enabled = true, speed = 4, bezier = "smooth" })

hl.animation({
    leaf = "windowsIn",
    enabled = true,
    speed = 5,
    bezier = "smooth",
    style = "popin 93%"
})

hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 4,
    bezier = "smoothOut",
    style = "popin 92%"
})

hl.animation({
    leaf = "windowsMove",
    enabled = true,
    speed = 6,
    bezier = "smooth"
})

hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 6.5,
    bezier = "smooth",
    style = "slidevert"
})

hl.animation({
    leaf = "layersIn",
    enabled = true,
    speed = 4,
    bezier = "smooth",
    style = "fade"
})

hl.animation({
    leaf = "layersOut",
    enabled = true,
    speed = 3,
    bezier = "smoothOut",
    style = "fade"
})

hl.animation({ leaf = "fade",       enabled = true, speed = 4, bezier = "smooth" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 3, bezier = "smoothOut" })
hl.animation({ leaf = "border",     enabled = false })
hl.animation({ leaf = "fadeSwitch", enabled = false })
hl.animation({ leaf = "zoomFactor", enabled = false })
