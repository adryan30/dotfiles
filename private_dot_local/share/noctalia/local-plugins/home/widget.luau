--!nonstrict

local PANEL_ID = "potato/home:panel"
local ACTIVE_DOMAINS = { light = true, switch = true, input_boolean = true, fan = true, media_player = true, climate = true }

local home = noctalia.state.get("home") or { areas = {}, entities = {} }
local status = noctalia.state.get("status") or "unconfigured"

local function isActive(entity)
  if not entity or not ACTIVE_DOMAINS[entity.domain] then return false end
  local s = entity.state
  return s ~= "off" and s ~= "unavailable" and s ~= "unknown" and s ~= "standby" and s ~= "idle"
end

local function priorityArea()
  local value = noctalia.getConfig("priority_area")
  local wanted = type(value) == "string" and (string.lower(value):gsub("[^a-z0-9_]", "")) or ""
  if wanted == "" then return nil end
  for _, area in ipairs(home.areas or {}) do
    if string.find(string.lower(area.id or ""), wanted, 1, true)
      or string.find(string.lower(area.name or ""), wanted, 1, true) then
      return area
    end
  end
  return nil
end

local function roomTemperature(area)
  if not area then return nil end
  for _, id in ipairs(area.entities or {}) do
    local e = home.entities[id]
    if e and e.domain == "climate" and e.current then return e.current end
  end
  for _, id in ipairs(area.entities or {}) do
    local e = home.entities[id]
    if e and e.domain == "sensor" and e.device_class == "temperature" then
      local value = tonumber(e.state)
      if value then return value end
    end
  end
  return nil
end

-- Same rule as the panel: a climate entity's own switches/lights aren't separate devices.
local function isClimateCompanion(id, prefixes)
  if not (id:match("^switch%.") or id:match("^light%.")) then return false end
  local objectId = id:match("^[^.]+%.(.+)$") or ""
  for _, prefix in ipairs(prefixes) do
    if string.sub(objectId, 1, #prefix) == prefix then return true end
  end
  return false
end

local function activeCount()
  local count, counted = 0, {}
  for _, area in ipairs(home.areas or {}) do
    local prefixes = {}
    for _, id in ipairs(area.entities or {}) do
      local objectId = id:match("^climate%.(.+)$")
      if objectId then table.insert(prefixes, objectId .. "_") end
    end
    for _, id in ipairs(area.entities or {}) do
      if not counted[id] and not isClimateCompanion(id, prefixes) and isActive(home.entities[id]) then
        counted[id] = true
        count += 1
      end
    end
  end
  return count
end

local function render()
  local count = activeCount()

  local connected = status == "connected"
  local children = {
    ui.glyph({
      name = "smart-home",
      size = 16,
      color = connected and (count > 0 and "primary" or "on_surface") or "on_surface_variant",
    }),
  }
  if connected and count > 0 and noctalia.getConfig("show_count") ~= false then
    table.insert(children, ui.label({ text = tostring(count), fontWeight = "bold", color = "on_surface" }))
  end

  local container = barWidget.isVertical() and ui.column or ui.row
  barWidget.render(container({ gap = 5, align = "center" }, children))

  if not connected then
    barWidget.setTooltip(noctalia.tr("widget.tooltip_status", { status = noctalia.tr("status." .. status) }))
    return
  end
  local area = priorityArea()
  local temp = roomTemperature(area)
  if area and temp then
    barWidget.setTooltip(noctalia.tr("widget.tooltip_room", {
      count = count,
      room = area.name,
      temp = string.format("%.1f", temp),
    }))
  else
    barWidget.setTooltip(noctalia.tr("widget.tooltip", { count = count }))
  end
end

noctalia.state.watch("home", function(value)
  if type(value) == "table" then
    home = value
    render()
  end
end)

noctalia.state.watch("status", function(value)
  status = value or "unconfigured"
  render()
end)

render()

function update()
  render()
end

function onClick()
  noctalia.togglePanel(PANEL_ID)
end

-- For keybinds: noctalia msg plugin potato/home:home DP-1 panel
function onIpc(event, _payload)
  if event == "panel" then
    noctalia.togglePanel(PANEL_ID)
  end
end
