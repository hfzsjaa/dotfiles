local previous = rawget(_G, "__layoutmode_dispose")
if type(previous) == "function" then pcall(previous) end

local alive = true

local STATE_DIR = (os.getenv("HOME") or ".") .. "/.local/state/hypr"
local STATE_FILE = STATE_DIR .. "/layoutmode.lua"
local STATE_TMP = STATE_FILE .. ".tmp"
local MODE_FILE = STATE_DIR .. "/layout-mode"

local LAYOUT = { tile = "dwindle", float = "lua:floating" }

local PALETTE_FILE = (os.getenv("HOME") or ".") .. "/.config/hypr/matugen-colors.lua"

local function palette()
  local chunk = loadfile(PALETTE_FILE)
  if not chunk then return nil end
  local ok, p = pcall(chunk)
  if ok and type(p) == "table" then return p end
end

local function apply_colors(m)
  local p = palette()
  if not p then return end
  local active
  if m == "float" then
    active = { colors = { p.tertiary, p.secondary }, angle = 45 }
  else
    active = { colors = { p.primary, p.secondary }, angle = 45 }
  end
  pcall(hl.config, { general = { col = { active_border = active, inactive_border = p.inactive } } })
end

local SNAPSHOT_MS = 2000
local DEBUG = false

local PAN_STEP = 240
local SCROLL_PAN = 200
local DRAG_SENS = 1.6
local PAN_SMOOTH = 0.4
local PAN_TICK_MS = 16
local EDGE_SPEED = 39
local EDGE_TICK_MS = 30
local EDGE_DWELL = 8
local EDGE_PX = 1
local MOVE_EDGE_DWELL = 3
local EDGE_LEAVE_TICKS = 5
local EDGE_STEP = EDGE_SPEED * PAN_TICK_MS / EDGE_TICK_MS

local MDRAG_STALE_MOVES = 6
local MDRAG_BLIND_PX = 150

local MIN_W, MIN_H = 80, 60
local MAX_SIZE = 8000
local MAX_POS = 100000

local FOCUS_NAV_ALWAYS = false
local CYCLE_HOLD_S = 3

local DRAG_BUTTONS = {
  { "SUPER + SHIFT", "mouse:272" },
}

local MOVE_BUTTONS = {
  { "SUPER", "mouse:272" },
}

local function round(n)
  return math.floor(n + 0.5)
end

local function clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

local function num(v, default)
  if type(v) == "number" and v == v and v > -1e9 and v < 1e9 then return v end
  return default
end

local function log(msg)
  pcall(hl.print, "[layoutmode] " .. tostring(msg))
end

local function notify(text)
  pcall(hl.notification.create, { text = text, duration = 1200, icon = "info" })
end

local function safe(name, fn)
  return function(...)
    if not alive then return end
    local ok, err = pcall(fn, ...)
    if not ok then log(name .. ": " .. tostring(err)) end
  end
end

local timers = {}
local all_binds = {}

local function repeating(name, fn, ms, enabled)
  local t = hl.timer(safe(name, fn), { timeout = ms, type = "repeat" })
  timers[#timers + 1] = t
  if not enabled then pcall(t.set_enabled, t, false) end
  return t
end

local function oneshot(name, fn, ms)
  return hl.timer(safe(name, fn), { timeout = ms, type = "oneshot" })
end

local function switch(t, on)
  pcall(t.set_enabled, t, on)
end

local function switch_all(list, on)
  for _, h in ipairs(list) do switch(h, on) end
end

local MOVE_PROFILE = {
  idle = { enabled = true, speed = 1.8, bezier = "lm_quint" },
  toggle = { enabled = true, speed = 2.6, bezier = "lm_overshoot" },
  pan = { enabled = false, speed = 1, bezier = "lm_snap" },
}

local mdrag = nil
local anim_gen = 0
local anim_now = nil

local function animate(profile, force)
  anim_gen = anim_gen + 1
  if anim_now == profile and not force then return end
  anim_now = profile
  local p = MOVE_PROFILE[profile]
  pcall(hl.animation, { leaf = "windowsMove", enabled = p.enabled, speed = p.speed, bezier = p.bezier })
end

local function animate_back(ms)
  anim_gen = anim_gen + 1
  local gen = anim_gen
  oneshot("animate_back", function()
    if gen == anim_gen and not mdrag then animate("idle") end
  end, ms)
end

local function setup_animations()
  pcall(hl.curve, "lm_snap", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
  pcall(hl.curve, "lm_quint", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })
  pcall(hl.curve, "lm_overshoot", { type = "bezier", points = { { 0.22, 1.04 }, { 0.36, 1 } } })
  pcall(hl.animation, { leaf = "windowsIn", enabled = true, speed = 2.2, bezier = "lm_snap", style = "popin 88%" })
  pcall(hl.animation, { leaf = "windowsOut", enabled = true, speed = 1.6, bezier = "lm_quint", style = "popin 92%" })
  pcall(hl.animation, { leaf = "fadeIn", enabled = true, speed = 2.2, bezier = "lm_quint" })
  pcall(hl.animation, { leaf = "fadeOut", enabled = true, speed = 2, bezier = "lm_quint" })
  pcall(hl.animation, { leaf = "border", enabled = false })
  pcall(hl.animation, { leaf = "workspaces", enabled = true, speed = 3, bezier = "lm_snap", style = "slidevert" })
  animate("idle", true)
end

local bind_failures = 0

local function bind(keys, fn, opts)
  local wrapped = safe("bind " .. keys, function(...)
    if DEBUG then notify("bind: " .. keys .. (opts and opts.release and " (release)" or "")) end
    fn(...)
  end)
  local ok, handle = pcall(hl.bind, keys, wrapped, opts)
  if not ok then
    bind_failures = bind_failures + 1
    log("bind " .. keys .. " failed: " .. tostring(handle))
    return nil
  end
  if handle then all_binds[#all_binds + 1] = handle end
  return handle
end

local saved = { mode = "tile", view = { x = 0, y = 0 }, edge = false, float = {}, ws = {}, marks = {} }

local function valid_rect(c)
  return type(c) == "table"
      and num(c.x) and num(c.y) and num(c.w) and num(c.h)
      and math.abs(c.x) <= MAX_POS and math.abs(c.y) <= MAX_POS
      and c.w >= MIN_W and c.w <= MAX_SIZE
      and c.h >= MIN_H and c.h <= MAX_SIZE
end

local function parse_ids(v)
  if num(v) then return { round(v) } end
  if type(v) ~= "table" then return {} end
  local entries = {}
  for k, id in pairs(v) do
    local i = tonumber(k)
    if i and num(id) then entries[#entries + 1] = { i, round(id) } end
  end
  table.sort(entries, function(a, b) return a[1] < b[1] end)
  local ids = {}
  for i, e in ipairs(entries) do ids[i] = e[2] end
  return ids
end

local function read_mode_file()
  local f = io.open(MODE_FILE, "r")
  if not f then return nil end
  local m = f:read("*l")
  f:close()
  m = m and m:match("^%s*(%S+)%s*$")
  if m and LAYOUT[m] then return m end
end

local mode_loaded = false

local function load_state()
  local chunk = loadfile(STATE_FILE)
  if not chunk then return end
  local ok, data = pcall(chunk)
  if not (ok and type(data) == "table") then return end

  if LAYOUT[data.mode] then
    saved.mode = data.mode
    mode_loaded = true
  end
  saved.edge = data.edge == true

  if type(data.view) == "table" then
    saved.view.x = round(clamp(num(data.view.x, 0), -MAX_POS, MAX_POS))
    saved.view.y = round(clamp(num(data.view.y, 0), -MAX_POS, MAX_POS))
  end

  if type(data.float) == "table" then
    for class, v in pairs(data.float) do
      if type(class) == "string" and type(v) == "table" then
        local list = {}
        if valid_rect(v) then
          list[1] = { x = round(v.x), y = round(v.y), w = round(v.w), h = round(v.h) }
        else
          for k, c in pairs(v) do
            local i = tonumber(k)
            if i and valid_rect(c) then
              list[round(i)] = { x = round(c.x), y = round(c.y), w = round(c.w), h = round(c.h) }
            end
          end
        end
        if next(list) then saved.float[class] = list end
      end
    end
  end

  if type(data.marks) == "table" then
    for k, m in pairs(data.marks) do
      if type(m) == "table" and num(m.x) and num(m.y) then
        saved.marks[tostring(k)] = { x = round(m.x), y = round(m.y) }
      end
    end
  end

  if type(data.ws) == "table" then
    for class, v in pairs(data.ws) do
      if type(class) == "string" then
        local ids = parse_ids(v)
        if #ids > 0 then saved.ws[class] = ids end
      end
    end
  end
end

load_state()
if not mode_loaded then
  saved.mode = read_mode_file() or saved.mode
end

local dirty = false
os.execute("mkdir -p '" .. STATE_DIR .. "'")

local function serialize(v)
  if type(v) == "table" then
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for i, k in ipairs(keys) do
      out[i] = string.format("[%q]=%s", tostring(k), serialize(v[k]))
    end
    return "{" .. table.concat(out, ",") .. "}"
  elseif type(v) == "string" then
    return string.format("%q", v)
  end
  return tostring(v)
end

local function flush()
  if not dirty then return end
  local f = io.open(STATE_TMP, "w")
  if not f then return end
  f:write("return ", serialize(saved), "\n")
  f:close()
  if os.rename(STATE_TMP, STATE_FILE) then dirty = false end
end

local mode = saved.mode

local function publish_mode()
  local f = io.open(MODE_FILE, "w")
  if not f then return end
  f:write(mode, "\n")
  f:close()
end

local live = { canvas = {}, order = {}, kept = {}, home = {}, float_ws = nil }
local view = { x = 0, y = 0 }

local settling, settle_gen = false, 0
local session = nil

pcall(hl.layout.register, "floating", {
  recalculate = function(ctx)
    local n = #ctx.targets
    for i, target in ipairs(ctx.targets) do
      target:place(ctx:column(i, n))
    end
  end,
})

local function managed()
  local list = {}
  for _, w in ipairs(hl.get_windows()) do
    if w.workspace and not w.workspace.special and (w.fullscreen or 0) == 0 then
      list[#list + 1] = w
    end
  end
  return list
end

local function window_by_addr(addr)
  for _, w in ipairs(hl.get_windows()) do
    if w.address == addr then return w end
  end
end

local function active_window()
  local ok, w = pcall(hl.get_active_window)
  if ok and type(w) == "table" and w.address then return w end
end

local function class_of(w)
  local class = w.class
  if class and class ~= "" then return class end
end

local function monitor_size(m)
  return m.width / m.scale, m.height / m.scale
end

local function geometry(w)
  local m, at, size = w.monitor, w.at, w.size
  if not (m and at and size) then return nil end
  return {
    x = round(at.x - m.x),
    y = round(at.y - m.y),
    w = round(size.x),
    h = round(size.y),
  }
end

local function same(a, b)
  return a and b and a.x == b.x and a.y == b.y and a.w == b.w and a.h == b.h
end

local function to_canvas(g)
  return { x = g.x + view.x, y = g.y + view.y, w = g.w, h = g.h }
end

local function to_screen(c)
  return { x = c.x - view.x, y = c.y - view.y, w = c.w, h = c.h }
end

local function addr_less(a, b)
  if #a ~= #b then return #a < #b end
  return a < b
end

local function effective_home(w)
  return live.home[w.address] or (w.workspace and w.workspace.id)
end

local function by_class(wins)
  local groups = {}
  for _, w in ipairs(wins or managed()) do
    local class = class_of(w)
    if class then
      groups[class] = groups[class] or {}
      table.insert(groups[class], w)
    end
  end
  for _, list in pairs(groups) do
    table.sort(list, function(a, b) return addr_less(a.address, b.address) end)
  end
  return groups
end

local function class_slot(w)
  local class = class_of(w)
  if not class then return nil end
  for i, x in ipairs(by_class()[class] or {}) do
    if x.address == w.address then return i end
  end
end

local function saved_rect(w)
  local class = class_of(w)
  local list = class and saved.float[class]
  if not list then return nil end
  local slot = class_slot(w)
  return slot and list[slot]
end

local function remember(w, c, slot)
  if not valid_rect(c) then return end
  if not same(live.canvas[w.address], c) then live.canvas[w.address] = c end
  local class = class_of(w)
  slot = slot or class_slot(w)
  if class and slot then
    local list = saved.float[class]
    if not list then
      list = {}
      saved.float[class] = list
    end
    if not same(list[slot], c) then
      list[slot] = c
      dirty = true
    end
  end
end

local function same_ids(a, b)
  if not (a and b) or #a ~= #b then return false end
  for i = 1, #a do
    if a[i] ~= b[i] then return false end
  end
  return true
end

local function sync_homes(wins)
  for class, list in pairs(by_class(wins)) do
    local ids = {}
    for i, w in ipairs(list) do ids[i] = effective_home(w) end
    if not same_ids(saved.ws[class], ids) then
      saved.ws[class] = ids
      dirty = true
    end
  end
end

local function resolve_homes()
  local wins = managed()
  local homes = {}
  for class, list in pairs(by_class(wins)) do
    local ids = saved.ws[class]
    for i, w in ipairs(list) do
      homes[w.address] = live.home[w.address] or (ids and ids[i])
    end
  end
  for _, w in ipairs(wins) do
    if homes[w.address] == nil then homes[w.address] = live.home[w.address] end
  end
  return homes
end

local function arm_settle()
  settling = true
  settle_gen = settle_gen + 1
  local gen = settle_gen
  oneshot("settle", function()
    if gen == settle_gen then settling = false end
  end, 400)
end

local function snapshot_float()
  if settling or session then return end
  local wins = managed()
  sync_homes(wins)
  local slot = {}
  for _, list in pairs(by_class(wins)) do
    for i, w in ipairs(list) do slot[w.address] = i end
  end
  for _, w in ipairs(wins) do
    if w.floating then
      local g = geometry(w)
      if g then remember(w, to_canvas(g), slot[w.address]) end
    end
  end
end

local function master_rank(w)
  return (w.layout and w.layout.is_master) and 0 or 1
end

local function snapshot_tile()
  local per_ws = {}
  local wins = managed()
  live.kept = {}
  sync_homes(wins)
  for _, w in ipairs(wins) do
    local id = w.workspace.id
    if w.floating then
      live.kept[w.address] = geometry(w)
    else
      per_ws[id] = per_ws[id] or {}
      table.insert(per_ws[id], w)
    end
  end
  for id, list in pairs(per_ws) do
    table.sort(list, function(a, b)
      local am, bm = master_rank(a), master_rank(b)
      if am ~= bm then return am < bm end
      if a.at.y ~= b.at.y then return a.at.y < b.at.y end
      return a.at.x < b.at.x
    end)
    local addrs = {}
    for i, w in ipairs(list) do addrs[i] = w.address end
    live.order[id] = addrs
  end
end

local function snapshot()
  if mode == "float" then snapshot_float() else snapshot_tile() end
end

local function move_to(w, c)
  local s = to_screen(c)
  hl.dispatch(hl.dsp.window.move({ x = s.x, y = s.y, relative = false, window = w }))
end

local function place(w, c)
  local cw = clamp(c.w, MIN_W, MAX_SIZE)
  local ch = clamp(c.h, MIN_H, MAX_SIZE)
  hl.dispatch(hl.dsp.window.resize({ x = cw, y = ch, relative = false, window = w }))
  move_to(w, c)
end

local function screen_size()
  local m = hl.get_active_monitor()
  if not (m and m.scale and m.scale > 0) then return nil end
  return monitor_size(m)
end

local function cursor()
  local a, b = hl.get_cursor_pos()
  if type(a) == "table" then return num(a.x or a[1], 0), num(a.y or a[2], 0) end
  return num(a, 0), num(b, 0)
end

local function cursor_inside(w)
  local g = geometry(w)
  if not g then return false end
  local m = w.monitor
  local x, y = cursor()
  x, y = x - (m and m.x or 0), y - (m and m.y or 0)
  return x >= g.x and x <= g.x + g.w and y >= g.y and y <= g.y + g.h
end

local function active_workspace_id()
  local ok, ws = pcall(hl.get_active_workspace)
  if ok and type(ws) == "table" and ws.id then return ws.id end
  local m = hl.get_active_monitor()
  return m and m.active_workspace and m.active_workspace.id
end

local function send_to_workspace(w, id)
  hl.dispatch(hl.dsp.window.move({ workspace = id, follow = false, window = w }))
end

local function gather(w)
  live.float_ws = live.float_ws or active_workspace_id()
  local target, current = live.float_ws, w.workspace and w.workspace.id
  if not target or not current or current == target then return end
  live.home[w.address] = live.home[w.address] or current
  send_to_workspace(w, target)
end

local function save_view()
  if mode ~= "float" then return end
  if saved.view.x ~= view.x or saved.view.y ~= view.y then
    saved.view.x, saved.view.y = view.x, view.y
    dirty = true
  end
end

local function intersects(c, v, sw, sh)
  return c.x - v.x < sw and c.x + c.w - v.x > 0 and c.y - v.y < sh and c.y + c.h - v.y > 0
end

local function apply_view()
  for _, w in ipairs(managed()) do
    local c = w.floating and live.canvas[w.address]
    if c and not (mdrag and mdrag.addr == w.address) then pcall(move_to, w, c) end
  end
  arm_settle()
end

local function session_begin()
  if session then return false end
  local sw, sh = screen_size()
  local items = {}
  for _, w in ipairs(managed()) do
    local c = w.floating and live.canvas[w.address]
    if c and not (mdrag and mdrag.addr == w.address) then items[#items + 1] = { w = w, c = c } end
  end
  session = { items = items, sw = sw, sh = sh }
  animate("pan")
  return true
end

local function session_move(nx, ny)
  if not session or (nx == view.x and ny == view.y) then return end
  local px, py = view.x, view.y
  view.x, view.y = nx, ny
  if mdrag and mdrag.addr then
    local dw = window_by_addr(mdrag.addr)
    local g = dw and geometry(dw)
    if g then live.canvas[mdrag.addr] = to_canvas(g) end
  end
  local sw, sh = session.sw, session.sh
  local cur, prev = view, { x = px, y = py }
  for _, it in ipairs(session.items) do
    local skip = mdrag and mdrag.addr == it.w.address
    if not skip and (not sw or intersects(it.c, cur, sw, sh) or intersects(it.c, prev, sw, sh)) then
      pcall(move_to, it.w, it.c)
    end
  end
end

local function session_end()
  if not session then return end
  session = nil
  apply_view()
  save_view()
  animate_back(80)
end

local edge = { ticks = 0, off = 0, active = false }
local edge_v = nil
local edge_timer, edge_sync

local drag = nil
local release_ok = true
local drag_timer
local release_binds = {}

local function arm_release()
  switch_all(release_binds, drag ~= nil or mdrag ~= nil)
end

local pan_target, pan_timer, pan_running = nil, nil, false

local function pan_release()
  if session and not (pan_target or drag or edge.active) then session_end() end
end

local function pan_stop_timer()
  if pan_running then
    pan_running = false
    switch(pan_timer, false)
  end
end

local function pan_cancel()
  pan_target = nil
  pan_stop_timer()
  pan_release()
end

local function pan_to(tx, ty)
  if mode ~= "float" then return end
  pan_target = { x = round(clamp(tx, -MAX_POS, MAX_POS)), y = round(clamp(ty, -MAX_POS, MAX_POS)) }
  if not session then session_begin() end
  if not pan_running then
    pan_running = true
    switch(pan_timer, true)
  end
end

local function pan_step(d)
  if d == 0 then return 0 end
  local s = d * PAN_SMOOTH
  if math.abs(s) < 1 then return d > 0 and 1 or -1 end
  return round(s)
end

pan_timer = repeating("pan", function()
  local ev = edge_v
  if ev and not edge.active then
    edge_v = nil
    ev = nil
  end
  if ev then
    if not session then session_begin() end
    session_move(
      round(clamp(view.x + round(ev.x), -MAX_POS, MAX_POS)),
      round(clamp(view.y + round(ev.y), -MAX_POS, MAX_POS))
    )
    return
  end
  local t = pan_target
  if not t then
    pan_stop_timer()
    return
  end
  local dx, dy = t.x - view.x, t.y - view.y
  if dx == 0 and dy == 0 then
    pan_target = nil
    pan_stop_timer()
    pan_release()
    return
  end
  if not session then session_begin() end
  session_move(view.x + pan_step(dx), view.y + pan_step(dy))
end, PAN_TICK_MS, false)

local function reset_view()
  if drag or edge.active then return end
  pan_cancel()
  view.x, view.y = 0, 0
  apply_view()
  save_view()
end

local function drag_stop()
  if not drag then return end
  drag = nil
  switch(drag_timer, false)
  arm_release()
  edge.ticks = 0
  edge.active = false
  edge_v = nil
  pan_release()
  edge_sync()
end

local function drag_start()
  if drag then
    drag_stop()
    if not release_ok then return end
  end
  if mode ~= "float" then return end
  local sx, sy = cursor()
  if not session then session_begin() end
  drag = { sx = sx, sy = sy, vx = view.x, vy = view.y, fresh = true }
  switch(drag_timer, true)
  arm_release()
  edge_sync()
end

drag_timer = repeating("drag", function()
  if not drag then return end
  drag.fresh = false
  local x, y = cursor()
  pan_to(drag.vx - (x - drag.sx) * DRAG_SENS, drag.vy - (y - drag.sy) * DRAG_SENS)
end, PAN_TICK_MS, false)

local function drag_release()
  if not drag then return end
  if drag.fresh then
    if release_ok then
      release_ok = false
      log("release events not delivered; using click-to-drop")
      notify("Pan: release binds unsupported, click again to drop")
    end
    return
  end
  drag_stop()
end

local function pan_screen(dx, dy)
  if mode ~= "float" then return end
  if drag then drag.vx, drag.vy = drag.vx + dx, drag.vy + dy end
  local t = pan_target
  pan_to((t and t.x or view.x) + dx, (t and t.y or view.y) + dy)
end

local function edge_release()
  edge.ticks = 0
  edge.off = 0
  edge_v = nil
  if edge.active then
    edge.active = false
    pan_release()
  end
end

local function edge_dir(p, size)
  if p <= EDGE_PX then return -1 end
  if p >= size - 1 - EDGE_PX then return 1 end
  return 0
end

local function drop_move_drag()
  mdrag = nil
  arm_release()
  edge_sync()
  animate_back(80)
end

local function track_dragged()
  local cx, cy = cursor()
  local now = {}
  for _, w in ipairs(managed()) do
    if w.floating and w.at then now[w.address] = { x = w.at.x, y = w.at.y } end
  end
  local prev = mdrag.prev
  mdrag.prev = { cx = cx, cy = cy, pos = now }
  if not prev then return end
  local dx, dy = cx - prev.cx, cy - prev.cy
  if math.abs(dx) < 2 and math.abs(dy) < 2 then return end
  mdrag.travel = mdrag.travel + math.abs(dx) + math.abs(dy)

  local following = false
  if mdrag.addr then
    local p, q = now[mdrag.addr], prev.pos[mdrag.addr]
    following = p ~= nil and q ~= nil
        and math.abs((p.x - q.x) - dx) <= 2 and math.abs((p.y - q.y) - dy) <= 2
  else
    for addr, p in pairs(now) do
      local q = prev.pos[addr]
      if q and math.abs((p.x - q.x) - dx) <= 2 and math.abs((p.y - q.y) - dy) <= 2 then
        mdrag.addr = addr
        following = true
        break
      end
    end
  end

  if following then
    mdrag.misses = 0
    return
  end
  mdrag.misses = mdrag.misses + 1
  if mdrag.addr and mdrag.misses >= MDRAG_STALE_MOVES then
    drop_move_drag()
  elseif not mdrag.addr and mdrag.travel >= MDRAG_BLIND_PX then
    drop_move_drag()
  end
end

local function edge_tick()
  if mdrag then track_dragged() end
  local m = hl.get_active_monitor()
  if not (m and m.scale and m.scale > 0) then return end
  local sw, sh = monitor_size(m)
  local x, y = cursor()
  local dx, dy = edge_dir(x - m.x, sw), edge_dir(y - m.y, sh)
  if drag then
    edge_v = nil
    edge.active = false
    edge.ticks = 0
    if not drag.fresh then
      drag.vx = drag.vx - dx * EDGE_SPEED
      drag.vy = drag.vy - dy * EDGE_SPEED
    end
    return
  end
  if dx == 0 and dy == 0 then
    edge_v = nil
    edge.off = edge.off + 1
    if edge.off >= EDGE_LEAVE_TICKS then edge_release() end
    return
  end
  edge.off = 0
  edge.ticks = edge.ticks + 1
  if edge.ticks < (mdrag and MOVE_EDGE_DWELL or EDGE_DWELL) then return end
  if mdrag and not mdrag.addr then
    local aw = active_window()
    if aw and aw.floating and cursor_inside(aw) then mdrag.addr = aw.address end
    if not mdrag.addr and not saved.edge then
      edge.ticks = 0
      return
    end
  end
  if not edge.active then
    if not session then session_begin() end
    edge.active = true
  end
  pan_target = nil
  edge_v = { x = dx * EDGE_STEP, y = dy * EDGE_STEP }
  if not pan_running then
    pan_running = true
    switch(pan_timer, true)
  end
end

edge_timer = repeating("edge", edge_tick, EDGE_TICK_MS, false)

edge_sync = function()
  local want = mode == "float" and (saved.edge or drag ~= nil or mdrag ~= nil)
  switch(edge_timer, want)
  if not want then edge_release() end
end

local function edge_toggle()
  saved.edge = not saved.edge
  dirty = true
  edge_sync()
  notify("Edge pan: " .. (saved.edge and "on" or "off"))
end

local function move_drag_start()
  if mode ~= "float" or drag then return end
  mdrag = { addr = nil, travel = 0, misses = 0 }
  animate("pan")
  arm_release()
  edge_sync()
end

local function move_drag_stop()
  if not mdrag then return end
  local addr = mdrag.addr
  local w = addr and window_by_addr(addr)
  local g = w and geometry(w)
  if g then remember(w, to_canvas(g)) end
  mdrag = nil
  arm_release()
  edge_sync()
  animate_back(80)
end

local function default_canvas(w, i)
  local sw, sh = monitor_size(w.monitor)
  local gw, gh = round(sw * 0.6), round(sh * 0.6)
  local off = (i % 8) * 40
  return {
    x = round(view.x + (sw - gw) / 2) + off,
    y = round(view.y + (sh - gh) / 2) + off,
    w = gw,
    h = gh,
  }
end

local function centered_on_cursor(w, c)
  local m = w.monitor
  local sw, sh = monitor_size(m)
  local cx, cy = cursor()
  return {
    x = view.x + round(clamp(cx - m.x - c.w / 2, 0, math.max(0, sw - c.w))),
    y = view.y + round(clamp(cy - m.y - c.h / 2, 0, math.max(0, sh - c.h))),
    w = c.w,
    h = c.h,
  }
end

local function float_window(w, i, opts)
  opts = opts or {}
  local g = geometry(w)
  local c = live.canvas[w.address] or saved_rect(w)
  if not w.floating then
    hl.dispatch(hl.dsp.window.float({ action = "set", window = w }))
    c = c or default_canvas(w, i)
  elseif not c then
    if not g then return end
    c = to_canvas(g)
    remember(w, c)
    if not opts.at_cursor then return end
  end
  if opts.at_cursor then c = centered_on_cursor(w, c) end
  live.canvas[w.address] = c
  place(w, c)
end

local function new_window_goes_first()
  if LAYOUT.tile ~= "master" then return false end
  local ok, status = pcall(hl.get_config, "master.new_status")
  return ok and status == "master"
end

local function tile_queue()
  local wins, by_addr, queue, seen = managed(), {}, {}, {}
  for _, w in ipairs(wins) do by_addr[w.address] = w end
  for _, addrs in pairs(live.order) do
    for _, addr in ipairs(addrs) do
      local w = by_addr[addr]
      if w and not seen[addr] then
        seen[addr] = true
        queue[#queue + 1] = w
      end
    end
  end
  for _, w in ipairs(wins) do
    if not seen[w.address] then queue[#queue + 1] = w end
  end
  return queue
end

local function float_all()
  for i, w in ipairs(managed()) do
    gather(w)
    float_window(w, i)
  end
  arm_settle()
end

local function enter_float()
  view.x, view.y = saved.view.x, saved.view.y
  live.float_ws = active_workspace_id()
  float_all()
end

local function adopt_windows()
  live.float_ws = live.float_ws or active_workspace_id()
  local homes = resolve_homes()
  for _, w in ipairs(managed()) do
    if homes[w.address] and not live.home[w.address] then
      live.home[w.address] = homes[w.address]
    end
  end
  float_all()
end

local function enter_tile()
  local homes = resolve_homes()
  view.x, view.y = 0, 0
  live.float_ws = nil
  local queue = tile_queue()
  if new_window_goes_first() then
    for i = 1, math.floor(#queue / 2) do
      queue[i], queue[#queue - i + 1] = queue[#queue - i + 1], queue[i]
    end
  end
  for _, w in ipairs(queue) do
    local home = homes[w.address]
    live.home[w.address] = nil
    if home and w.workspace and w.workspace.id ~= home then
      send_to_workspace(w, home)
    end
    local kept = live.kept[w.address]
    if w.floating then
      if kept and valid_rect(kept) then
        place(w, kept)
      else
        hl.dispatch(hl.dsp.window.float({ action = "unset", window = w }))
      end
    end
  end
end

local SNAP_GAP = 8
local TIDY_GAP = 16

local SNAPS = {
  left = { 0, 0, 0.5, 1 },
  right = { 0.5, 0, 0.5, 1 },
  top = { 0, 0, 1, 0.5 },
  bottom = { 0, 0.5, 1, 0.5 },
  tl = { 0, 0, 0.5, 0.5 },
  tr = { 0.5, 0, 0.5, 0.5 },
  bl = { 0, 0.5, 0.5, 0.5 },
  br = { 0.5, 0.5, 0.5, 0.5 },
  full = { 0, 0, 1, 1 },
  center = { 0.2, 0.2, 0.6, 0.6 },
}

local SNAP_KEYS = {
  { "left",   "left" },
  { "right",  "right" },
  { "up",     "top" },
  { "down",   "bottom" },
  { "Y",      "tl" },
  { "U",      "tr" },
  { "B",      "bl" },
  { "N",      "br" },
  { "Return", "full" },
  { "C",      "center" },
}

local function floating_windows()
  local list = {}
  for _, w in ipairs(managed()) do
    if w.floating and live.canvas[w.address] then list[#list + 1] = w end
  end
  return list
end

local function glide(nx, ny)
  if drag or edge.active then return end
  pan_cancel()
  view.x, view.y = round(clamp(nx, -MAX_POS, MAX_POS)), round(clamp(ny, -MAX_POS, MAX_POS))
  animate("toggle")
  apply_view()
  save_view()
  animate_back(500)
end

local function mark_save(n)
  saved.marks[n] = { x = view.x, y = view.y }
  dirty = true
  notify("Mark " .. n .. " saved")
end

local function mark_go(n)
  local m = saved.marks[n]
  if not m then
    notify("Mark " .. n .. " empty")
    return
  end
  glide(m.x, m.y)
end

local function mark_delete(n)
  if not saved.marks[n] then
    notify("Mark " .. n .. " empty")
    return
  end
  saved.marks[n] = nil
  dirty = true
  notify("Mark " .. n .. " deleted")
end

local function mark_clear()
  if next(saved.marks) == nil then
    notify("No marks")
    return
  end
  saved.marks = {}
  dirty = true
  notify("All marks deleted")
end

local function fits_view(c, sw, sh)
  return c.x >= view.x and c.y >= view.y and c.x + c.w <= view.x + sw and c.y + c.h <= view.y + sh
end

local function reveal(w, always)
  local sw, sh = screen_size()
  local g = geometry(w)
  local c = g and to_canvas(g) or live.canvas[w.address]
  if not (c and sw) then return end
  if not always and fits_view(c, sw, sh) then return end
  remember(w, c)
  glide(c.x + c.w / 2 - sw / 2, c.y + c.h / 2 - sh / 2)
end

local function jump_to(w)
  reveal(w, true)
  pcall(function() hl.dispatch(hl.dsp.focus({ window = w })) end)
end

local cycle_last = { addr = nil, at = 0 }

local function cycle(step)
  local list = floating_windows()
  if #list == 0 then return end
  table.sort(list, function(a, b)
    local ca, cb = live.canvas[a.address], live.canvas[b.address]
    if ca.x ~= cb.x then return ca.x < cb.x end
    if ca.y ~= cb.y then return ca.y < cb.y end
    return addr_less(a.address, b.address)
  end)
  local active = active_window()
  local current = active and active.address
  if cycle_last.addr and os.time() - cycle_last.at <= CYCLE_HOLD_S then
    current = cycle_last.addr
  end
  local idx = 0
  for i, w in ipairs(list) do
    if w.address == current then
      idx = i
      break
    end
  end
  local nxt = idx == 0 and (step > 0 and 1 or #list) or ((idx - 1 + step) % #list + 1)
  cycle_last = { addr = list[nxt].address, at = os.time() }
  jump_to(list[nxt])
end

local function snap_active(kind)
  local w, s = active_window(), SNAPS[kind]
  if not (w and s and w.floating and w.monitor) then return end
  local sw, sh = monitor_size(w.monitor)
  local c = {
    x = view.x + round(sw * s[1]) + SNAP_GAP,
    y = view.y + round(sh * s[2]) + SNAP_GAP,
    w = round(sw * s[3]) - 2 * SNAP_GAP,
    h = round(sh * s[4]) - 2 * SNAP_GAP,
  }
  remember(w, c)
  place(w, c)
end

local function tidy()
  if session then return end
  local sw, sh = screen_size()
  local list = floating_windows()
  local n = #list
  if not sw or n == 0 then return end
  table.sort(list, function(a, b)
    local ca, cb = live.canvas[a.address], live.canvas[b.address]
    if ca.y ~= cb.y then return ca.y < cb.y end
    return ca.x < cb.x
  end)
  local cols = math.ceil(math.sqrt(n))
  local rows = math.ceil(n / cols)
  local cw = (sw - TIDY_GAP * (cols + 1)) / cols
  local ch = (sh - TIDY_GAP * (rows + 1)) / rows
  animate("toggle")
  for i, w in ipairs(list) do
    local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
    local c = {
      x = view.x + round(TIDY_GAP + col * (cw + TIDY_GAP)),
      y = view.y + round(TIDY_GAP + row * (ch + TIDY_GAP)),
      w = round(cw),
      h = round(ch),
    }
    remember(w, c)
    place(w, c)
  end
  arm_settle()
  animate_back(500)
end

local function summon()
  if session then return end
  local sw, sh = screen_size()
  if not sw then return end
  animate("toggle")
  for _, w in ipairs(floating_windows()) do
    local c = live.canvas[w.address]
    local moved = {
      x = clamp(c.x, view.x, view.x + math.max(0, sw - c.w)),
      y = clamp(c.y, view.y, view.y + math.max(0, sh - c.h)),
      w = c.w,
      h = c.h,
    }
    if not same(moved, c) then
      remember(w, moved)
      move_to(w, moved)
    end
  end
  arm_settle()
  animate_back(500)
end

local canvas_binds = {}

local function add_canvas_bind(keys, fn, opts)
  local h = bind(keys, function(...)
    if mode == "float" then fn(...) end
  end, opts)
  if h then canvas_binds[#canvas_binds + 1] = h end
end

add_canvas_bind("SUPER + ALT + left", function() pan_screen(-PAN_STEP, 0) end)
add_canvas_bind("SUPER + ALT + right", function() pan_screen(PAN_STEP, 0) end)
add_canvas_bind("SUPER + ALT + up", function() pan_screen(0, -PAN_STEP) end)
add_canvas_bind("SUPER + ALT + down", function() pan_screen(0, PAN_STEP) end)
add_canvas_bind("SUPER + ALT + 0", function()
  drag_stop()
  reset_view()
end)
add_canvas_bind("SUPER + ALT + E", edge_toggle)

add_canvas_bind("SUPER + CTRL + mouse_up", function() pan_screen(0, -SCROLL_PAN) end)
add_canvas_bind("SUPER + CTRL + mouse_down", function() pan_screen(0, SCROLL_PAN) end)
add_canvas_bind("SUPER + CTRL + SHIFT + mouse_up", function() pan_screen(-SCROLL_PAN, 0) end)
add_canvas_bind("SUPER + CTRL + SHIFT + mouse_down", function() pan_screen(SCROLL_PAN, 0) end)

add_canvas_bind("SUPER + ALT + T", tidy)
add_canvas_bind("SUPER + ALT + S", summon)
add_canvas_bind("SUPER + Z", function() cycle(1) end)
add_canvas_bind("SUPER + X", function() cycle(-1) end)

for i = 1, 9 do
  local n = tostring(i)
  add_canvas_bind("SUPER + ALT + " .. n, function() mark_go(n) end)
  add_canvas_bind("SUPER + ALT + SHIFT + " .. n, function() mark_save(n) end)
  add_canvas_bind("SUPER + ALT + CTRL + " .. n, function() mark_delete(n) end)
end

add_canvas_bind("SUPER + ALT + CTRL + 0", mark_clear)

for _, k in ipairs(SNAP_KEYS) do
  add_canvas_bind("SUPER + CTRL + " .. k[1], function() snap_active(k[2]) end)
end

local function add_drag_binds(mods, button)
  local list = {}
  for part in mods:gmatch("[^%s+]+") do list[#list + 1] = part end
  add_canvas_bind(mods .. " + " .. button, drag_start)
  local n = #list
  for mask = 2 ^ n - 1, 1, -1 do
    local parts = {}
    for i = 1, n do
      if math.floor(mask / 2 ^ (i - 1)) % 2 == 1 then parts[#parts + 1] = list[i] end
    end
    local full = #parts == n
    add_canvas_bind(
      table.concat(parts, " + ") .. " + " .. button,
      drag_release,
      full and { release = true } or { release = true, non_consuming = true }
    )
  end
end

for _, d in ipairs(DRAG_BUTTONS) do add_drag_binds(d[1], d[2]) end

for _, d in ipairs(MOVE_BUTTONS) do
  local keys = d[1] .. " + " .. d[2]
  add_canvas_bind(keys, move_drag_start, { non_consuming = true })
  add_canvas_bind(keys, move_drag_stop, { release = true, non_consuming = true })
end

local release_buttons = {}

local function add_release_button(button)
  if release_buttons[button] then return end
  release_buttons[button] = true
  local h = bind(button, function()
    drag_release()
    move_drag_stop()
  end, { release = true, non_consuming = true })
  if h then
    release_binds[#release_binds + 1] = h
    switch(h, false)
  end
end

for _, d in ipairs(DRAG_BUTTONS) do add_release_button(d[2]) end
for _, d in ipairs(MOVE_BUTTONS) do add_release_button(d[2]) end

local workspace_binds = {}

local function add_workspace_bind(keys, dsp)
  local h = bind(keys, function() hl.dispatch(dsp) end)
  if h then workspace_binds[#workspace_binds + 1] = h end
end

for i = 1, 10 do
  local key = i % 10
  add_workspace_bind("SUPER + " .. key, hl.dsp.focus({ workspace = i }))
  add_workspace_bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

local function sync_binds()
  switch_all(canvas_binds, mode == "float")
  switch_all(workspace_binds, mode ~= "float")
  if mode ~= "float" then
    drag_stop()
    move_drag_stop()
  end
  edge_sync()
end

local function set_mode(target)
  if target == mode or not LAYOUT[target] then return end
  apply_colors(mode)
  move_drag_stop()
  drag_stop()
  edge_release()
  pan_cancel()
  snapshot()

  mode = target
  animate("toggle")
  if mode == "float" then
    enter_float()
    hl.config({ general = { layout = LAYOUT.float } })
  else
    hl.config({ general = { layout = LAYOUT.tile } })
    enter_tile()
  end
  sync_binds()
  animate_back(500)
  publish_mode()

  saved.mode = mode
  dirty = true
  flush()
end

local function toggle()
  set_mode(mode == "tile" and "float" or "tile")
end

local function on_ready()
  hl.config({ general = { layout = LAYOUT[mode] } })
  apply_colors(mode)
  setup_animations()
  drag_stop()
  move_drag_stop()
  edge_release()
  pan_cancel()
  session = nil
  sync_binds()
  if mode == "float" then adopt_windows() end
end

hl.config({ general = { layout = LAYOUT[mode] } })
if mode == "float" then view.x, view.y = saved.view.x, saved.view.y end
setup_animations()
sync_binds()
publish_mode()

bind("SUPER + Space", toggle, { description = "Toggle tile/float layout" })

hl.on("window.open", safe("window.open", function(w)
  if mode == "float" and w.workspace and not w.workspace.special then
    gather(w)
    float_window(w, w.workspace.windows or 0, { at_cursor = true })
    arm_settle()
  end
end))

hl.on("window.close", safe("window.close", function(w)
  if mode == "float" then snapshot_float() end
  live.canvas[w.address] = nil
  live.kept[w.address] = nil
  live.home[w.address] = nil
end))

hl.on("window.active", safe("window.active", function(w)
  if mode ~= "float" or session or drag or mdrag or edge.active or pan_running or settling then return end
  if type(w) ~= "table" or not w.floating or (w.fullscreen or 0) ~= 0 then return end
  if not w.workspace or w.workspace.special or not live.canvas[w.address] then return end
  if cursor_inside(w) then return end
  reveal(w, FOCUS_NAV_ALWAYS)
end))

hl.on("hyprland.start", safe("hyprland.start", on_ready))
hl.on("config.reloaded", safe("config.reloaded", on_ready))

hl.on("hyprland.shutdown", safe("hyprland.shutdown", function()
  snapshot()
  flush()
end))

if bind_failures > 0 then
  notify(string.format("layoutmode: %d binds failed, see hyprctl rollinglog", bind_failures))
end

repeating("snapshot", function()
  if mode == "float" and not (drag or edge.active or pan_running) then snapshot_float() end
  flush()
end, SNAPSHOT_MS, true)

if mode == "float" then oneshot("adopt", adopt_windows, 150) end

local function dispose()
  if not alive then return end
  pcall(snapshot)
  pcall(flush)
  alive = false
  switch_all(timers, false)
  switch_all(all_binds, false)
end

rawset(_G, "__layoutmode_dispose", dispose)

return { toggle = toggle, set = set_mode, get = function() return mode end }