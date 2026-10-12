--!nonstrict

local tr = noctalia.tr

-- How long a locally adjusted target wins over the reported one while HA catches up.
local DRAFT_TIMEOUT_SECONDS = 6

local MODES = {
  { id = "auto", glyph = "settings-automation" },
  { id = "cool", glyph = "snowflake" },
  { id = "dry", glyph = "droplet" },
  { id = "fan_only", glyph = "wind" },
  { id = "heat", glyph = "flame" },
}

local PRESETS = {
  { id = "none", glyph = "circle-off" },
  { id = "eco", glyph = "leaf" },
  { id = "sleep", glyph = "zzz" },
  { id = "boost", glyph = "rocket" },
  { id = "away", glyph = "home-2" },
}

local FANS = { "silent", "low", "medium", "high", "max", "auto" }

local SWINGS = {
  { id = "off", glyph = "circle-off" },
  { id = "vertical", glyph = "arrows-vertical" },
  { id = "horizontal", glyph = "arrows-horizontal" },
  { id = "both", glyph = "arrows-move" },
}

local ac = noctalia.state.get("ac") or { available = false }
local status = noctalia.state.get("status") or "unconfigured"
local draftTarget = nil
local draftSince = 0
local commandId = 0
local render

local function contains(list, value)
  if type(list) ~= "table" then return false end
  for _, item in ipairs(list) do
    if item == value then return true end
  end
  return false
end

local function isOn()
  return ac.available == true and ac.hvac ~= nil and ac.hvac ~= "off"
end

local function send(domain, service, data, role)
  commandId += 1
  noctalia.state.set("command", {
    id = `panel-{commandId}`,
    domain = domain,
    service = service,
    data = data,
    entity_role = role,
  })
end

local function shownTarget()
  if draftTarget and os.clock() - draftSince < DRAFT_TIMEOUT_SECONDS then
    return draftTarget
  end
  draftTarget = nil
  return ac.target
end

local function formatTemp(value)
  if value == nil then return "–" end
  if value == math.floor(value) then return string.format("%d", value) end
  return string.format("%.1f", value)
end

local function nudgeTarget(direction)
  local current = shownTarget()
  if current == nil then return end
  local step = ac.step or 1
  local next = math.clamp(current + direction * step, ac.min or 16, ac.max or 30)
  if next == current then return end
  draftTarget = next
  draftSince = os.clock()
  send("climate", "set_temperature", { temperature = next })
  render()
end

local function sectionLabel(text)
  return ui.label({ text = text, fontSize = 12, color = "on_surface_variant" })
end

local function choiceButton(props)
  props.variant = props.selected and "primary" or "outline"
  props.flexGrow = 1
  props.controlSize = "sm"
  return ui.button(props)
end

local function subtitle()
  if status ~= "connected" then return tr("status." .. status) end
  if not ac.available then return tr("status.unavailable") end
  local parts = {}
  if ac.current then table.insert(parts, tr("panel.room", { temp = formatTemp(ac.current) })) end
  if ac.outdoor then table.insert(parts, tr("panel.outside", { temp = formatTemp(ac.outdoor) })) end
  if isOn() and ac.power then
    table.insert(parts, tr("panel.power", { watts = math.floor(ac.power + 0.5) }))
  end
  if not isOn() then table.insert(parts, tr("status.off")) end
  return table.concat(parts, "  ·  ")
end

local function header()
  local on = isOn()
  return ui.row({ align = "center", gap = 8 }, {
    ui.glyph({ name = "air-conditioning", size = 24, color = on and "primary" or "on_surface_variant" }),
    ui.column({ flexGrow = 1, gap = 0 }, {
      ui.label({ text = ac.name or tr("title"), fontSize = 18, fontWeight = "bold" }),
      ui.label({ text = subtitle(), fontSize = 11, color = "on_surface_variant", maxLines = 1 }),
    }),
    ui.button({
      glyph = "power",
      variant = on and "primary" or "outline",
      selected = on,
      onClick = function()
        send("climate", on and "turn_off" or "turn_on")
      end,
    }),
    ui.button({ glyph = "x", variant = "ghost", onClick = function() panel.close() end }),
  })
end

local function temperatureCard()
  local target = shownTarget()
  local on = isOn()
  return ui.row({ align = "center", gap = 12, padding = 12, fill = "surface_variant/0.45", radius = 12 }, {
    ui.button({ glyph = "minus", variant = "outline", onClick = function() nudgeTarget(-1) end }),
    ui.column({ flexGrow = 1, gap = 0, align = "center" }, {
      ui.label({
        text = `{formatTemp(target)}°`,
        fontSize = 40,
        fontWeight = "bold",
        color = on and (ac.preset == "boost" and "error" or "primary") or "on_surface_variant",
      }),
      ui.label({
        text = on and tr("modes." .. ac.hvac) or tr("status.off"),
        fontSize = 12,
        color = "on_surface_variant",
      }),
    }),
    ui.button({ glyph = "plus", variant = "outline", onClick = function() nudgeTarget(1) end }),
  })
end

local function modeRow()
  local buttons = {}
  for _, mode in ipairs(MODES) do
    if contains(ac.hvac_modes, mode.id) then
      table.insert(buttons, choiceButton({
        text = tr("modes." .. mode.id),
        glyph = mode.glyph,
        selected = ac.hvac == mode.id,
        onClick = function() send("climate", "set_hvac_mode", { hvac_mode = mode.id }) end,
      }))
    end
  end
  return ui.column({ gap = 6 }, { sectionLabel(tr("panel.mode")), ui.row({ gap = 6 }, buttons) })
end

local function presetRow()
  local buttons = {}
  for _, preset in ipairs(PRESETS) do
    if contains(ac.preset_modes, preset.id) then
      table.insert(buttons, choiceButton({
        text = tr("presets." .. preset.id),
        glyph = preset.glyph,
        selected = (ac.preset or "none") == preset.id,
        onClick = function() send("climate", "set_preset_mode", { preset_mode = preset.id }) end,
      }))
    end
  end
  local children = { sectionLabel(tr("panel.preset")), ui.row({ gap = 6 }, buttons) }
  if not contains(ac.preset_modes, "boost") then
    table.insert(children, ui.label({ text = tr("panel.turbo_hint"), fontSize = 11, color = "on_surface_variant" }))
  end
  return ui.column({ gap = 6 }, children)
end

local function fanRow()
  local buttons = {}
  for _, fan in ipairs(FANS) do
    if contains(ac.fan_modes, fan) then
      table.insert(buttons, choiceButton({
        text = tr("fans." .. fan),
        selected = ac.fan == fan,
        onClick = function() send("climate", "set_fan_mode", { fan_mode = fan }) end,
      }))
    end
  end
  return ui.column({ gap = 6 }, { sectionLabel(tr("panel.fan")), ui.row({ gap = 6 }, buttons) })
end

local function swingRow()
  local buttons = {}
  for _, swing in ipairs(SWINGS) do
    if contains(ac.swing_modes, swing.id) then
      table.insert(buttons, choiceButton({
        text = tr("swings." .. swing.id),
        glyph = swing.glyph,
        selected = ac.swing == swing.id,
        onClick = function() send("climate", "set_swing_mode", { swing_mode = swing.id }) end,
      }))
    end
  end
  return ui.column({ gap = 6 }, { sectionLabel(tr("panel.swing")), ui.row({ gap = 6 }, buttons) })
end

local function extrasRow()
  local buttons = {}
  local function toggle(role, glyph, label)
    local value = ac[role]
    if value == nil then return end
    table.insert(buttons, choiceButton({
      text = label,
      glyph = glyph,
      selected = value == true,
      onClick = function() send("switch", "toggle", {}, role) end,
    }))
  end
  toggle("display", "device-desktop", tr("panel.display"))
  toggle("purifier", "sparkles", tr("panel.purifier"))
  if #buttons == 0 then return nil end
  return ui.column({ gap = 6 }, { sectionLabel(tr("panel.extras")), ui.row({ gap = 6 }, buttons) })
end

render = function()
  local children = { header() }
  if status == "connected" and ac.available then
    table.insert(children, temperatureCard())
    table.insert(children, modeRow())
    table.insert(children, presetRow())
    table.insert(children, fanRow())
    table.insert(children, swingRow())
    local extras = extrasRow()
    if extras then table.insert(children, extras) end
  end
  panel.render(ui.column({ flexGrow = 1, gap = 14 }, children))
end

noctalia.state.watch("ac", function(value)
  if type(value) ~= "table" then return end
  ac = value
  if draftTarget and ac.target == draftTarget then draftTarget = nil end
  render()
end)

noctalia.state.watch("status", function(value)
  status = value or "unconfigured"
  render()
end)

function onOpen(_context)
  ac = noctalia.state.get("ac") or ac
  status = noctalia.state.get("status") or status
  panel.setWantsSecondTicks(true)
  render()
end

function onClose()
  panel.setWantsSecondTicks(false)
end

function update()
  if draftTarget and os.clock() - draftSince >= DRAFT_TIMEOUT_SECONDS then
    draftTarget = nil
    render()
  end
end

render()
