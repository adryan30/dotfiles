--!nonstrict

local PANEL_ID = "potato/midea-ac:panel"

local MODE_GLYPHS = {
  cool = "snowflake",
  dry = "droplet",
  fan_only = "wind",
  heat = "flame",
}

local ac = noctalia.state.get("ac") or { available = false }
local status = noctalia.state.get("status") or "unconfigured"
local commandId = 0

local function isOn()
  return ac.available == true and ac.hvac ~= nil and ac.hvac ~= "off"
end

local function stateText()
  if status ~= "connected" then
    return noctalia.tr("status." .. status)
  end
  if not ac.available then
    return noctalia.tr("status.unavailable")
  end
  if not isOn() then
    return noctalia.tr("status.off")
  end
  local parts = { noctalia.tr("modes." .. ac.hvac) }
  if ac.target then table.insert(parts, `{ac.target}°`) end
  if ac.preset and ac.preset ~= "none" then
    table.insert(parts, noctalia.tr("presets." .. ac.preset))
  end
  if ac.power then table.insert(parts, noctalia.tr("panel.power", { watts = math.floor(ac.power + 0.5) })) end
  return table.concat(parts, " · ")
end

local function render()
  local on = isOn()
  local color = on and (ac.preset == "boost" and "error" or "primary") or "on_surface_variant"
  local children = {
    ui.glyph({
      name = on and (MODE_GLYPHS[ac.hvac] or "air-conditioning") or "air-conditioning",
      size = 16,
      color = color,
    }),
  }

  if noctalia.getConfig("show_temperature") ~= false and ac.available and ac.current then
    table.insert(children, ui.label({
      text = string.format("%.0f°", ac.current),
      fontWeight = "bold",
      color = on and "on_surface" or "on_surface_variant",
    }))
  end

  local container = barWidget.isVertical() and ui.column or ui.row
  barWidget.render(container({ gap = 5, align = "center" }, children))
  barWidget.setTooltip(noctalia.tr("widget.tooltip", {
    name = ac.name or noctalia.tr("title"),
    state = stateText(),
  }))
end

noctalia.state.watch("ac", function(value)
  if type(value) == "table" then
    ac = value
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

local function send(service, data)
  if status ~= "connected" or not ac.available then return end
  commandId += 1
  noctalia.state.set("command", {
    id = `widget-{commandId}`,
    domain = "climate",
    service = service,
    data = data,
  })
end

function onRightClick()
  send(isOn() and "turn_off" or "turn_on")
end

-- For keybinds: noctalia msg plugin potato/midea-ac:ac all <panel|power|turbo>
function onIpc(event, _payload)
  if event == "panel" then
    noctalia.togglePanel(PANEL_ID)
  elseif event == "power" then
    send(isOn() and "turn_off" or "turn_on")
  elseif event == "turbo" then
    send("set_preset_mode", { preset_mode = ac.preset == "boost" and "none" or "boost" })
  end
end
