--!nonstrict

local tr = noctalia.tr

-- Optimistic state wins over the reported one for this long while HA catches up.
local PENDING_TIMEOUT_SECONDS = 5
-- Brightness drags are sent once the slider has been still this long.
local SLIDER_SETTLE_SECONDS = 0.3

local DOMAIN_ORDER = {
  climate = 1, light = 2, switch = 3, input_boolean = 3, fan = 4,
  media_player = 5, cover = 6, lock = 7,
}

local SENSOR_ORDER = { temperature = 1, humidity = 2, power = 3, battery = 4 }
local SENSOR_GLYPHS = { temperature = "temperature", humidity = "droplet", power = "bolt", battery = "battery" }

local home = noctalia.state.get("home") or { areas = {}, entities = {} }
local status = noctalia.state.get("status") or "unconfigured"
local expanded = {}
local pending = {}
local brightnessDraft = {}
local targetDraft = {}
local commandId = 0
local render

local function send(domain, service, data)
  commandId += 1
  noctalia.state.set("command", { id = `panel-{commandId}`, domain = domain, service = service, data = data })
end

local function setPending(id, key, value)
  pending[id] = pending[id] or {}
  pending[id][key] = { value = value, since = os.clock() }
end

local function pendingValue(id, key)
  local entry = pending[id] and pending[id][key]
  if not entry then return nil end
  if os.clock() - entry.since >= PENDING_TIMEOUT_SECONDS then
    pending[id][key] = nil
    return nil
  end
  return entry.value
end

local function reconcile()
  for id, keys in pairs(pending) do
    local e = home.entities[id]
    for key, entry in pairs(keys) do
      local reported = e and (key == "state" and e.state or e[key])
      if reported == entry.value or os.clock() - entry.since >= PENDING_TIMEOUT_SECONDS then
        keys[key] = nil
      end
    end
  end
end

local function isUnavailable(e)
  return e.state == "unavailable" or e.state == "unknown"
end

local function isOn(e)
  local s = pendingValue(e.id, "state") or e.state
  return s ~= "off" and s ~= "unavailable" and s ~= "unknown" and s ~= "standby" and s ~= "idle" and s ~= "closed" and s ~= "locked"
end

local function priorityKey()
  local value = noctalia.getConfig("priority_area")
  return type(value) == "string" and (string.lower(value):gsub("[^a-z0-9_]", "")) or ""
end

local function isPriority(area)
  local wanted = priorityKey()
  if wanted == "" then return false end
  return string.find(string.lower(area.id or ""), wanted, 1, true) ~= nil
    or string.find(string.lower(area.name or ""), wanted, 1, true) ~= nil
end

local function orderedAreas()
  local list = {}
  for _, area in ipairs(home.areas or {}) do table.insert(list, area) end
  table.sort(list, function(a, b)
    local pa, pb = isPriority(a), isPriority(b)
    if pa ~= pb then return pa end
    return string.lower(a.name or a.id) < string.lower(b.name or b.id)
  end)
  return list
end

local function isExpanded(area)
  local value = expanded[area.id]
  if value == nil then return isPriority(area) end
  return value
end

local function displayName(e, area)
  local name = e.name or e.id
  local room = area.name or ""
  if room ~= "" then
    local lowerName, lowerRoom = string.lower(name), string.lower(room)
    if string.sub(lowerName, 1, #lowerRoom + 1) == lowerRoom .. " " then
      name = string.sub(name, #room + 2)
    elseif #lowerName > #lowerRoom + 1 and string.sub(lowerName, -(#lowerRoom + 1)) == " " .. lowerRoom then
      name = string.sub(name, 1, #name - #room - 1)
    end
  end
  return name
end

local function formatNumber(value)
  if value == nil then return "–" end
  if value == math.floor(value) then return string.format("%d", value) end
  return string.format("%.1f", value)
end

-- Switches/lights named after a climate entity in the same room (e.g. adryan_ac_display)
-- are that AC's own settings and belong in its detail panel, not the room list.
local function climateCompanionPrefixes(area)
  local prefixes = {}
  for _, id in ipairs(area.entities or {}) do
    local objectId = id:match("^climate%.(.+)$")
    if objectId then table.insert(prefixes, objectId .. "_") end
  end
  return prefixes
end

local function isClimateCompanion(e, prefixes)
  if e.domain ~= "switch" and e.domain ~= "light" then return false end
  local objectId = e.id:match("^[^.]+%.(.+)$") or ""
  for _, prefix in ipairs(prefixes) do
    if string.sub(objectId, 1, #prefix) == prefix then return true end
  end
  return false
end

local function splitArea(area)
  local devices, sensors = {}, {}
  local prefixes = climateCompanionPrefixes(area)
  for _, id in ipairs(area.entities or {}) do
    local e = home.entities[id]
    if e and not isUnavailable(e) and not isClimateCompanion(e, prefixes) then
      if e.domain == "sensor" then table.insert(sensors, e) else table.insert(devices, e) end
    end
  end
  table.sort(devices, function(a, b)
    local oa, ob = DOMAIN_ORDER[a.domain] or 9, DOMAIN_ORDER[b.domain] or 9
    if oa ~= ob then return oa < ob end
    return string.lower(a.name) < string.lower(b.name)
  end)
  table.sort(sensors, function(a, b)
    local oa, ob = SENSOR_ORDER[a.device_class] or 9, SENSOR_ORDER[b.device_class] or 9
    if oa ~= ob then return oa < ob end
    return string.lower(a.name) < string.lower(b.name)
  end)
  return devices, sensors
end

local function activeCount(devices)
  local count = 0
  for _, e in ipairs(devices) do
    if e.domain ~= "cover" and e.domain ~= "lock" and isOn(e) then count += 1 end
  end
  return count
end

-- Actions ----------------------------------------------------------------

local function toggle(e)
  if isUnavailable(e) then return end
  local on = isOn(e)
  setPending(e.id, "state", on and "off" or "on")
  if e.domain == "climate" or e.domain == "media_player" then
    send(e.domain, on and "turn_off" or "turn_on", { entity_id = e.id })
  else
    send("homeassistant", on and "turn_off" or "turn_on", { entity_id = e.id })
  end
  render()
end

local function nudgeTarget(e, direction)
  local draft = targetDraft[e.id]
  local current = (draft and os.clock() - draft.since < PENDING_TIMEOUT_SECONDS) and draft.value or e.target
  if current == nil then return end
  local step = e.step or 1
  local next = math.clamp(current + direction * step, e.min or 16, e.max or 30)
  if next == current then return end
  targetDraft[e.id] = { value = next, since = os.clock() }
  send("climate", "set_temperature", { entity_id = e.id, temperature = next })
  render()
end

local function shownTarget(e)
  local draft = targetDraft[e.id]
  if draft and os.clock() - draft.since < PENDING_TIMEOUT_SECONDS and draft.value ~= e.target then
    return draft.value
  end
  targetDraft[e.id] = nil
  return e.target
end

local function shownBrightness(e)
  local draft = brightnessDraft[e.id]
  if draft then return draft.value end
  if e.brightness then return math.max(1, math.floor(e.brightness / 255 * 100 + 0.5)) end
  return 100
end

-- Rows -------------------------------------------------------------------

local function deviceGlyph(e, on)
  local d = e.domain
  if d == "light" then return on and "bulb" or "bulb-off" end
  if d == "switch" or d == "input_boolean" then return on and "toggle-right" or "toggle-left" end
  if d == "fan" then return "propeller" end
  if d == "climate" then return "air-conditioning" end
  if d == "media_player" then return "device-tv" end
  if d == "lock" then return on and "lock-open" or "lock" end
  if d == "cover" then return "window" end
  return "smart-home"
end

local function subtitle(e, on)
  if isUnavailable(e) then return tr("panel.unavailable") end
  local d = e.domain
  if d == "light" then
    if not on then return tr("panel.off") end
    if e.dimmable then return tr("panel.brightness", { percent = shownBrightness(e) }) end
    return tr("panel.on")
  end
  if d == "climate" then
    if not on then return tr("panel.off") end
    local parts = { e.state }
    if e.current then table.insert(parts, `{formatNumber(e.current)}°`) end
    local target = shownTarget(e)
    if target then table.insert(parts, tr("panel.target", { temp = formatNumber(target) })) end
    return table.concat(parts, " · ")
  end
  if d == "media_player" then
    if e.media_title and e.media_title ~= "" and on then return e.media_title end
    local key = "media." .. e.state
    local text = tr(key)
    return text ~= key and text or e.state
  end
  if d == "cover" or d == "lock" then return e.state end
  return on and tr("panel.on") or tr("panel.off")
end

local function deviceRow(e, area)
  local on = isOn(e) and not isUnavailable(e)
  local unavailable = isUnavailable(e)
  local d = e.domain

  local mainButton
  if d == "cover" then
    mainButton = ui.button({ glyph = deviceGlyph(e, on), variant = "outline", onClick = function() end })
  else
    mainButton = ui.button({
      glyph = deviceGlyph(e, on),
      variant = on and "primary" or "outline",
      selected = on,
      onClick = function() toggle(e) end,
    })
  end

  local row = {
    mainButton,
    ui.column({ flexGrow = 1, gap = 1 }, {
      ui.label({ text = displayName(e, area), fontWeight = "medium", maxLines = 1,
        color = unavailable and "on_surface_variant" or "on_surface" }),
      ui.label({ text = subtitle(e, on), fontSize = 11, color = "on_surface_variant", maxLines = 1 }),
    }),
  }

  if d == "climate" and not unavailable then
    table.insert(row, ui.button({ glyph = "minus", variant = "ghost", controlSize = "sm", onClick = function() nudgeTarget(e, -1) end }))
    table.insert(row, ui.button({ glyph = "plus", variant = "ghost", controlSize = "sm", onClick = function() nudgeTarget(e, 1) end }))
    local detail = noctalia.getConfig("climate_panel")
    if type(detail) == "string" and detail ~= "" then
      table.insert(row, ui.button({ glyph = "adjustments", variant = "ghost", controlSize = "sm", onClick = function()
        noctalia.togglePanel(detail)
      end }))
    end
  elseif d == "media_player" and on then
    table.insert(row, ui.button({
      glyph = e.state == "playing" and "player-pause" or "player-play",
      variant = "ghost",
      controlSize = "sm",
      onClick = function() send("media_player", "media_play_pause", { entity_id = e.id }) end,
    }))
  elseif d == "cover" and not unavailable then
    table.insert(row, ui.button({ glyph = "arrow-up", variant = "ghost", controlSize = "sm",
      onClick = function() send("cover", "open_cover", { entity_id = e.id }) end }))
    table.insert(row, ui.button({ glyph = "arrow-down", variant = "ghost", controlSize = "sm",
      onClick = function() send("cover", "close_cover", { entity_id = e.id }) end }))
  end

  local children = { ui.row({ align = "center", gap = 10 }, row) }

  if d == "light" and e.dimmable and on then
    table.insert(children, ui.row({ align = "center", gap = 8 }, {
      ui.box({ width = 38, height = 1 }),
      ui.slider({
        key = "brightness-" .. e.id,
        min = 1,
        max = 100,
        step = 1,
        value = shownBrightness(e),
        flexGrow = 1,
        onChange = function(value)
          brightnessDraft[e.id] = { value = math.floor((tonumber(value) or 100) + 0.5), since = os.clock(), sent = false }
          render()
        end,
      }),
    }))
  end

  return ui.column({ gap = 6 }, children)
end

local function sensorStrip(sensors)
  if #sensors == 0 then return nil end
  local items = {}
  for _, e in ipairs(sensors) do
    local value = tonumber(e.state)
    if value then
      local unit = e.unit or ""
      table.insert(items, ui.row({ align = "center", gap = 4, padding = 6, fill = "surface/0.6", radius = 8 }, {
        ui.glyph({ name = SENSOR_GLYPHS[e.device_class] or "chart-line", size = 14, color = "secondary" }),
        ui.label({ text = formatNumber(value) .. (unit == "%" and "%" or (unit ~= "" and (" " .. unit) or "")), fontSize = 12 }),
      }))
    end
  end
  if #items == 0 then return nil end
  return ui.row({ gap = 6 }, items)
end

local function areaCard(area)
  local devices, sensors = splitArea(area)
  local open = isExpanded(area)
  local count = activeCount(devices)

  local headerChildren = {
    ui.button({
      text = area.name or area.id,
      glyph = open and "chevron-down" or "chevron-right",
      variant = "ghost",
      contentAlign = "start",
      flexGrow = 1,
      onClick = function()
        expanded[area.id] = not open
        render()
      end,
    }),
  }
  if count > 0 then
    table.insert(headerChildren, ui.label({ text = tr("panel.active_count", { count = count }), fontSize = 11, color = "primary" }))
  end

  local children = { ui.row({ align = "center", gap = 6 }, headerChildren) }
  if open then
    local strip = sensorStrip(sensors)
    if strip then table.insert(children, strip) end
    for _, e in ipairs(devices) do
      table.insert(children, deviceRow(e, area))
    end
  end

  return ui.column({
    gap = 8,
    padding = 10,
    radius = 12,
    fill = isPriority(area) and "primary/0.08" or "surface_variant/0.45",
  }, children)
end

-- Panel ------------------------------------------------------------------

render = function()
  reconcile()

  local cards = {}
  for _, area in ipairs(orderedAreas()) do
    local devices, sensors = splitArea(area)
    if #devices > 0 or #sensors > 0 then
      table.insert(cards, areaCard(area))
    end
  end

  local body
  if status ~= "connected" then
    body = ui.label({ text = tr("status." .. status), color = status == "connecting" and "on_surface_variant" or "error" })
  elseif #cards == 0 then
    body = ui.label({ text = tr("panel.empty"), color = "on_surface_variant" })
  else
    body = ui.scroll({ flexGrow = 1, gap = 10 }, cards)
  end

  panel.render(ui.column({ flexGrow = 1, gap = 12 }, {
    ui.row({ align = "center", gap = 8 }, {
      ui.glyph({ name = "smart-home", size = 22, color = status == "connected" and "primary" or "on_surface_variant" }),
      ui.label({ text = tr("title"), fontSize = 18, fontWeight = "bold", flexGrow = 1 }),
      ui.button({ glyph = "refresh", variant = "ghost", onClick = function()
        commandId += 1
        noctalia.state.set("command", { id = `panel-{commandId}`, action = "refresh" })
      end }),
      ui.button({ glyph = "x", variant = "ghost", onClick = function() panel.close() end }),
    }),
    body,
  }))
end

noctalia.state.watch("home", function(value)
  if type(value) ~= "table" then return end
  home = value
  render()
end)

noctalia.state.watch("status", function(value)
  status = value or "unconfigured"
  render()
end)

function onOpen(_context)
  home = noctalia.state.get("home") or home
  status = noctalia.state.get("status") or status
  panel.setWantsSecondTicks(true)
  render()
end

function onClose()
  panel.setWantsSecondTicks(false)
end

function update()
  local now = os.clock()
  local changed = false
  for id, draft in pairs(brightnessDraft) do
    if not draft.sent and now - draft.since >= SLIDER_SETTLE_SECONDS then
      draft.sent = true
      draft.since = now
      send("light", "turn_on", { entity_id = id, brightness_pct = draft.value })
    elseif draft.sent and now - draft.since >= PENDING_TIMEOUT_SECONDS then
      brightnessDraft[id] = nil
      changed = true
    end
  end
  if changed then render() end
end

render()
