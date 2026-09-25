--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

hl.layer_rule({
    match = { namespace = "^island-osd$" },
    animation = "slide bottom",
})

hl.layer_rule({
    match = { namespace = "^island-notif$" },
    animation = "fade",
})

hl.layer_rule({
    match = { namespace = "^island-dashboard$" },
    animation = "fade",
})

hl.layer_rule({
    match = { namespace = "^island-clipboard$" },
    animation = "fade",
})

hl.layer_rule({
    match = { namespace = "^island-wallpaper$" },
    animation = "fade",
})

hl.layer_rule({
    match = { namespace = "^island-overview$" },
    animation = "fade",
})

hl.layer_rule({
    match = { namespace = "^island-launcher$" },
    animation = "fade",
})

local function readLayout()
    local f = io.open(os.getenv("HOME") .. "/.cache/hypr-layout", "r")
    if not f then return "scrolling" end
    local value = f:read("*l")
    f:close()
    return (value == "dwindle") and "dwindle" or "scrolling"
end

hl.config({
    general = {
        layout = readLayout(),
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "slave",
        mfact = "0.75",
        orientation = "top"
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})
