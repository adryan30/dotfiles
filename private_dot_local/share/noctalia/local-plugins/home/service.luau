--!nonstrict

-- Host limits: 30s transfer + 10s connect per request, 8 async callbacks per runtime.
local REQUEST_TIMEOUT_SECONDS = 35
-- HA pings /api/stream every 50s, so a longer silence is a dead socket.
local STREAM_IDLE_TIMEOUT_SECONDS = 120
-- update() ticks every few seconds; a much longer gap means the machine slept.
local RESUME_GAP_SECONDS = 30
local LAYOUT_REFRESH_SECONDS = 600
local TICK_MS = 5000
local BACKOFF_TICK_MS = 30000
local MAX_FAST_RETRIES = 6

-- One round trip for rooms, their devices and current state. Only the
-- attributes the panel renders are copied: arbitrary attributes can hold
-- datetimes, which break tojson.
local LAYOUT_TEMPLATE = [[
{%- set domains = ['light','switch','input_boolean','fan','climate','media_player','cover','lock','sensor'] -%}
{%- set sensor_classes = ['temperature','humidity','power','battery'] -%}
{%- set ns = namespace(areas=[], entities=[]) -%}
{%- for a in areas() -%}
  {%- set en = namespace(ids=[]) -%}
  {%- for e in area_entities(a) -%}
    {%- set d = e.split('.')[0] -%}
    {%- if d in domains and not is_hidden_entity(e) -%}
      {%- if d != 'sensor' or state_attr(e, 'device_class') in sensor_classes -%}
        {%- set en.ids = en.ids + [e] -%}
        {%- set ns.entities = ns.entities + [{
          'entity_id': e,
          'state': states(e),
          'attributes': {
            'friendly_name': state_attr(e, 'friendly_name'),
            'unit_of_measurement': state_attr(e, 'unit_of_measurement'),
            'device_class': state_attr(e, 'device_class'),
            'brightness': state_attr(e, 'brightness'),
            'supported_color_modes': (state_attr(e, 'supported_color_modes') or []) | list,
            'current_temperature': state_attr(e, 'current_temperature'),
            'temperature': state_attr(e, 'temperature'),
            'min_temp': state_attr(e, 'min_temp'),
            'max_temp': state_attr(e, 'max_temp'),
            'target_temp_step': state_attr(e, 'target_temp_step'),
            'media_title': state_attr(e, 'media_title'),
          }
        }] -%}
      {%- endif -%}
    {%- endif -%}
  {%- endfor -%}
  {%- if en.ids | count > 0 -%}
    {%- set ns.areas = ns.areas + [{'id': a, 'name': area_name(a), 'entities': en.ids}] -%}
  {%- endif -%}
{%- endfor -%}
{%- set seen = ns.entities | map(attribute='entity_id') | list -%}
{%- set px = namespace(ids=[]) -%}
{%- set key = '__PRIORITY__' -%}
{%- if key != '' -%}
  {%- for s in states if key in s.entity_id and s.domain in domains and s.entity_id not in seen and not is_hidden_entity(s.entity_id) -%}
    {%- set e = s.entity_id -%}
    {%- if s.domain != 'sensor' or state_attr(e, 'device_class') in sensor_classes -%}
      {%- set px.ids = px.ids + [e] -%}
      {%- set ns.entities = ns.entities + [{
        'entity_id': e,
        'state': states(e),
        'attributes': {
          'friendly_name': state_attr(e, 'friendly_name'),
          'unit_of_measurement': state_attr(e, 'unit_of_measurement'),
          'device_class': state_attr(e, 'device_class'),
          'brightness': state_attr(e, 'brightness'),
          'supported_color_modes': (state_attr(e, 'supported_color_modes') or []) | list,
          'current_temperature': state_attr(e, 'current_temperature'),
          'temperature': state_attr(e, 'temperature'),
          'min_temp': state_attr(e, 'min_temp'),
          'max_temp': state_attr(e, 'max_temp'),
          'target_temp_step': state_attr(e, 'target_temp_step'),
          'media_title': state_attr(e, 'media_title'),
        }
      }] -%}
    {%- endif -%}
  {%- endfor -%}
{%- endif -%}
{{ {'areas': ns.areas, 'entities': ns.entities, 'priority_extra': px.ids} | tojson }}
]]

local function configString(key, fallback)
  local value = noctalia.getConfig(key)
  if type(value) ~= "string" then return fallback end
  value = noctalia.string.trim(value)
  return value ~= "" and value or fallback
end

local function baseUrl()
  return (configString("ha_url", ""):gsub("/+$", ""))
end

local function token()
  return configString("ha_token", "")
end

local function isConfigured()
  return baseUrl() ~= "" and token() ~= ""
end

local status = "unconfigured"
local home = { areas = {}, entities = {} }
local known = {}
local streamHandle = nil
local probeInFlight = false
local probeStartedAt = 0
local layoutInFlight = false
local lastLayoutAt = 0
local lastStreamActivity = 0
local lastTick = os.time()
local retries = 0

local function setStatus(next, reason)
  if status == next then return end
  status = next
  noctalia.log("status -> " .. next .. (reason and (" (" .. reason .. ")") or ""))
  noctalia.state.set("status", status)
  if next == "auth_failed" then
    noctalia.notifyError(noctalia.tr("notifications.auth_failed"))
  end
  noctalia.setUpdateInterval(retries >= MAX_FAST_RETRIES and BACKOFF_TICK_MS or TICK_MS)
end

local function publish()
  noctalia.state.set("home", home)
end

local function hasDimmableMode(modes)
  if type(modes) ~= "table" then return false end
  for _, mode in ipairs(modes) do
    if mode ~= "onoff" then return true end
  end
  return false
end

local function toRecord(state)
  local a = state.attributes or {}
  local id = state.entity_id
  local previous = home.entities[id]
  local dimmable = hasDimmableMode(a.supported_color_modes)
  if a.supported_color_modes == nil and previous then
    dimmable = previous.dimmable
  end
  return {
    id = id,
    domain = id:match("^([^.]+)"),
    state = state.state,
    name = a.friendly_name or id,
    unit = a.unit_of_measurement,
    device_class = a.device_class,
    brightness = tonumber(a.brightness),
    dimmable = dimmable,
    current = tonumber(a.current_temperature),
    target = tonumber(a.temperature),
    min = tonumber(a.min_temp),
    max = tonumber(a.max_temp),
    step = tonumber(a.target_temp_step),
    media_title = a.media_title,
  }
end

local function request(endpoint, method, body, callback)
  local headers = { "Authorization: Bearer " .. token() }
  local encoded = nil
  if body then
    encoded = noctalia.json.encode(body)
    table.insert(headers, "Content-Type: application/json")
  end
  return noctalia.http({
    url = baseUrl() .. endpoint,
    method = method,
    body = encoded,
    headers = headers,
  }, function(response: HttpResponse)
    callback(response and response.status or 0, response and response.body or "")
  end)
end

-- Entity IDs are lowercase [a-z0-9_.]; anything else can't match and could break the template.
local function priorityKey()
  return (string.lower(configString("priority_area", "")):gsub("[^a-z0-9_]", ""))
end

local function mergePriorityExtras(areas, extras, key)
  if key == "" or type(extras) ~= "table" or #extras == 0 then return areas end
  for _, area in ipairs(areas) do
    local id, name = string.lower(area.id or ""), string.lower(area.name or "")
    if string.find(id, key, 1, true) or string.find(name, key, 1, true) then
      for _, entityId in ipairs(extras) do table.insert(area.entities, entityId) end
      return areas
    end
  end
  table.insert(areas, {
    id = key,
    name = string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2),
    entities = extras,
  })
  return areas
end

local function fetchLayout()
  if layoutInFlight then return end
  layoutInFlight = true
  lastLayoutAt = os.time()
  local key = priorityKey()
  local template = string.gsub(LAYOUT_TEMPLATE, "__PRIORITY__", key)
  local launched = request("/api/template", "POST", { template = template }, function(code, body)
    layoutInFlight = false
    if code < 200 or code >= 300 or body == "" then
      noctalia.log("layout template -> " .. tostring(code) .. " " .. body:sub(1, 200))
      return
    end
    local parsed = noctalia.json.decode(body)
    if type(parsed) ~= "table" or type(parsed.areas) ~= "table" then
      noctalia.log("layout template returned unexpected body")
      return
    end
    local entities = {}
    known = {}
    for _, state in ipairs(parsed.entities or {}) do
      if type(state) == "table" and state.entity_id then
        entities[state.entity_id] = toRecord(state)
        known[state.entity_id] = true
      end
    end
    home = { areas = mergePriorityExtras(parsed.areas, parsed.priority_extra, key), entities = entities }
    publish()
  end)
  if not launched then layoutInFlight = false end
end

local function handleLine(line)
  lastStreamActivity = os.time()
  local data = line:match("^data:%s*(.+)")
  if not data then return end
  -- The stream carries every entity in HA; skip the decode for the rest.
  local entityId = data:match('"entity_id"%s*:%s*"([^"]+)"')
  if not entityId or not known[entityId] then return end
  local parsed = noctalia.json.decode(data)
  if type(parsed) ~= "table" or parsed.event_type ~= "state_changed" then return end
  local inner = parsed.data or {}
  if inner.new_state then
    home.entities[entityId] = toRecord(inner.new_state)
    publish()
  end
end

local function stopStream()
  if streamHandle then
    streamHandle.stop()
    streamHandle = nil
  end
end

local function startStream()
  if streamHandle then return true end
  local handle
  handle = noctalia.httpStream({
    url = baseUrl() .. "/api/stream?restrict=state_changed",
    headers = {
      "Accept: text/event-stream",
      "Authorization: Bearer " .. token(),
    },
  }, handleLine, function(result)
    if streamHandle ~= handle then return end
    streamHandle = nil
    if result and (result.status == 401 or result.status == 403) then
      setStatus("auth_failed", "stream " .. tostring(result.status))
    else
      setStatus("connecting", "stream closed " .. tostring(result and result.status or 0))
    end
  end)
  if not handle then return false end
  streamHandle = handle
  lastStreamActivity = os.time()
  return true
end

local function connect()
  if probeInFlight or not isConfigured() then return end
  probeInFlight = true
  probeStartedAt = os.clock()
  local launched = request("/api/", "GET", nil, function(code)
    probeInFlight = false
    if code == 401 or code == 403 then
      setStatus("auth_failed", "http " .. tostring(code))
      return
    end
    if code < 200 or code >= 300 then
      retries += 1
      setStatus("unreachable", "http " .. tostring(code))
      return
    end
    if not startStream() then
      retries += 1
      setStatus("unreachable", "stream not started")
      return
    end
    retries = 0
    setStatus("connected", "api reachable")
    fetchLayout()
  end)
  if not launched then
    probeInFlight = false
    setStatus("unreachable", "request not launched")
  end
end

-- Commands from the widget and panel: { id, domain, service, data } or { id, action = "refresh" }.
noctalia.state.watch("command", function(cmd)
  if type(cmd) ~= "table" then return end
  if cmd.action == "refresh" then
    if status == "connected" then fetchLayout() else connect() end
    return
  end
  if status ~= "connected" or type(cmd.domain) ~= "string" or type(cmd.service) ~= "string" then
    return
  end
  request(`/api/services/{cmd.domain}/{cmd.service}`, "POST", cmd.data or {}, function(code)
    if code < 200 or code >= 300 then
      noctalia.log(`{cmd.domain}.{cmd.service} -> {code}`)
      noctalia.notifyError(noctalia.tr("notifications.command_failed", { status = code }))
    end
  end)
end)

function update()
  if not isConfigured() then
    stopStream()
    setStatus("unconfigured", "no url or token")
    return
  end

  local now = os.time()
  local gap = now - lastTick
  lastTick = now

  if streamHandle and (gap >= RESUME_GAP_SECONDS or now - lastStreamActivity > STREAM_IDLE_TIMEOUT_SECONDS) then
    stopStream()
    setStatus("connecting", "stale stream")
  end

  if probeInFlight and os.clock() - probeStartedAt > REQUEST_TIMEOUT_SECONDS then
    probeInFlight = false
  end
  if layoutInFlight and now - lastLayoutAt > REQUEST_TIMEOUT_SECONDS then
    layoutInFlight = false
  end

  if status == "connected" then
    if now - lastLayoutAt > LAYOUT_REFRESH_SECONDS then fetchLayout() end
  elseif status ~= "auth_failed" then
    connect()
  end
end

function onExit()
  stopStream()
end

noctalia.state.set("status", status)
publish()
noctalia.setUpdateInterval(TICK_MS)
if isConfigured() then
  setStatus("connecting", "startup")
  connect()
end
