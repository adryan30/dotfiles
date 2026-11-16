--!nonstrict

-- Host limits: 30s transfer + 10s connect per request, 8 async callbacks per runtime.
local REQUEST_TIMEOUT_SECONDS = 35
-- HA pings /api/stream every 50s, so a longer silence is a dead socket.
local STREAM_IDLE_TIMEOUT_SECONDS = 120
-- update() ticks every few seconds; a much longer gap means the machine slept.
local RESUME_GAP_SECONDS = 30
local TICK_MS = 5000
local BACKOFF_TICK_MS = 30000
local MAX_FAST_RETRIES = 6

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

local entityIds = {
  climate = configString("climate_entity", "climate.adryan_ac"),
  power = configString("power_entity", ""),
  outdoor = configString("outdoor_entity", ""),
  display = configString("display_entity", ""),
  purifier = configString("purifier_entity", ""),
}

local roleOf = {}
for role, id in pairs(entityIds) do
  if id ~= "" then roleOf[id] = role end
end

local status = "unconfigured"
local ac = { available = false }
local streamHandle = nil
local probeInFlight = false
local probeStartedAt = 0
local lastStreamActivity = 0
local lastTick = os.time()
local retries = 0
local currentData = nil

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
  noctalia.state.set("ac", ac)
end

local function numberOrNil(value)
  local n = tonumber(value)
  return n
end

local function applyState(entityId, state)
  local role = roleOf[entityId]
  if not role or type(state) ~= "table" then return end
  local value = state.state

  if role == "climate" then
    local a = state.attributes or {}
    ac.available = value ~= "unavailable" and value ~= "unknown"
    ac.name = a.friendly_name or entityId
    ac.hvac = value
    ac.hvac_modes = a.hvac_modes or {}
    ac.preset_modes = a.preset_modes or {}
    ac.fan_modes = a.fan_modes or {}
    ac.swing_modes = a.swing_modes or {}
    ac.current = numberOrNil(a.current_temperature)
    ac.target = numberOrNil(a.temperature)
    ac.min = numberOrNil(a.min_temp) or 16
    ac.max = numberOrNil(a.max_temp) or 30
    ac.step = numberOrNil(a.target_temp_step) or 1
    ac.fan = a.fan_mode
    ac.swing = a.swing_mode
    ac.preset = a.preset_mode
  elseif role == "power" or role == "outdoor" then
    ac[role] = numberOrNil(value)
  else
    ac[role] = value == "on" and true or (value == "off" and false or nil)
  end
  publish()
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
    local code = response and response.status or 0
    callback(code, response and response.body or "")
  end)
end

local function fetchSnapshot()
  for entityId in pairs(roleOf) do
    request("/api/states/" .. entityId, "GET", nil, function(code, body)
      if code >= 200 and code < 300 and body ~= "" then
        applyState(entityId, noctalia.json.decode(body))
      elseif code ~= 0 then
        noctalia.log("snapshot " .. entityId .. " -> " .. tostring(code))
      end
    end)
  end
end

local function handleLine(line)
  lastStreamActivity = os.time()
  if line == "" then
    currentData = nil
    return
  end
  local data = line:match("^data:%s*(.+)")
  if not data then return end
  -- Cheap substring check first; the stream carries every entity in HA.
  local matched = false
  for entityId in pairs(roleOf) do
    if data:find(entityId, 1, true) then
      matched = true
      break
    end
  end
  if not matched then return end
  local parsed = noctalia.json.decode(data)
  if type(parsed) ~= "table" or parsed.event_type ~= "state_changed" then return end
  local inner = parsed.data or {}
  if inner.entity_id and inner.new_state then
    applyState(inner.entity_id, inner.new_state)
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
    fetchSnapshot()
  end)
  if not launched then
    probeInFlight = false
    setStatus("unreachable", "request not launched")
  end
end

-- Commands come from the widget and panel as { id, domain, service, data }.
noctalia.state.watch("command", function(cmd)
  if type(cmd) ~= "table" or type(cmd.domain) ~= "string" or type(cmd.service) ~= "string" then
    return
  end
  if status ~= "connected" then return end
  local data = type(cmd.data) == "table" and cmd.data or {}
  if data.entity_id == nil then
    data.entity_id = cmd.entity_role and entityIds[cmd.entity_role] or entityIds.climate
  end
  request(`/api/services/{cmd.domain}/{cmd.service}`, "POST", data, function(code)
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

  if status ~= "connected" and status ~= "auth_failed" then
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
