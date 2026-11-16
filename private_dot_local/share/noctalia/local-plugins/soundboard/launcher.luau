--!nonstrict
-- Soundboard launcher provider: type /sb, pick a clip, plays into the soundboard sink
-- and (by default) mirrors to the default headset sink.

local AUDIO_EXTS = {
  [".mp3"] = true,
  [".wav"] = true,
  [".ogg"] = true,
  [".oga"] = true,
  [".flac"] = true,
  [".m4a"] = true,
  [".aac"] = true,
  [".opus"] = true,
  [".wma"] = true,
  [".aiff"] = true,
  [".aif"] = true,
}

local function trim(s)
  return (s or ""):match("^%s*(.-)%s*$") or ""
end

local function shellQuote(s)
  return "'" .. tostring(s):gsub("'", "'\"'\"'") .. "'"
end

local function clampVolume(v, fallback)
  if type(v) ~= "number" then
    return fallback
  end
  if v < 0 then
    return 0
  end
  if v > 1.5 then
    return 1.5
  end
  return v
end

local function pluginVolume()
  return clampVolume(noctalia.getConfig("volume"), 1.0)
end

-- Prefer ~/.config/soundboard/gui.json when present so /sb matches the GTK GUI.
local function guiConfig()
  local path = noctalia.expandPath("~/.config/soundboard/gui.json")
  if not noctalia.fileExists(path) then
    return nil
  end
  local raw = noctalia.readFile(path)
  if type(raw) ~= "string" or raw == "" then
    return nil
  end
  local data = noctalia.json.decode(raw)
  if type(data) ~= "table" then
    return nil
  end
  return data
end

local function clipsDir()
  local configured = noctalia.getConfig("clips_dir")
  if type(configured) == "string" and configured ~= "" then
    return noctalia.expandPath(configured)
  end
  return noctalia.expandPath("~/.local/share/soundboard/clips")
end

local function discordVolume()
  local gui = guiConfig()
  if gui and gui.discord_volume ~= nil then
    return clampVolume(gui.discord_volume, 1.0)
  end
  return pluginVolume()
end

local function headsetVolume()
  local gui = guiConfig()
  if gui and gui.headset_volume ~= nil then
    return clampVolume(gui.headset_volume, 0.7)
  end
  return pluginVolume()
end

local function alsoHeadset()
  local gui = guiConfig()
  if gui and gui.monitor ~= nil then
    return gui.monitor == true
  end
  local v = noctalia.getConfig("also_headset")
  if v == nil then
    return true
  end
  return v == true
end

local function stem(name)
  return name:match("(.+)%.[^%.]+$") or name
end

local function extension(name)
  local ext = name:match("(%.[^%.]+)$")
  return ext and ext:lower() or ""
end

local function listClips()
  local dir = clipsDir()
  local entries = noctalia.listDir(dir)
  if not entries then
    return {}, dir
  end
  local clips = {}
  for _, name in entries do
    if type(name) == "string" and AUDIO_EXTS[extension(name)] then
      local path = dir .. "/" .. name
      if noctalia.fileExists(path) then
        table.insert(clips, { name = name, path = path, title = stem(name) })
      end
    end
  end
  table.sort(clips, function(a, b)
    return a.title:lower() < b.title:lower()
  end)
  return clips, dir
end

local function makeRows(clips, filter, dir)
  local rows = {}
  for _, clip in clips do
    local score = nil
    if filter == "" then
      score = 0
    else
      score = noctalia.fuzzyScore(filter, clip.title)
      if score == nil then
        score = noctalia.fuzzyScore(filter, clip.name)
      end
    end
    if filter == "" or score ~= nil then
      table.insert(rows, {
        id = clip.path,
        title = clip.title,
        subtitle = clip.name,
        glyph = "player-play",
        score = filter == "" and nil or score,
      })
    end
  end
  if #rows == 0 then
    rows[1] = {
      id = "",
      title = noctalia.tr("no-clips"),
      subtitle = filter ~= "" and noctalia.tr("no-match", { filter = filter })
        or noctalia.tr("empty-dir", { dir = dir }),
      glyph = "mood-empty",
    }
  end
  return rows
end

function onQuery(query)
  local filter = trim(query)
  local clips, dir = listClips()
  launcher.setResults(query, makeRows(clips, filter, dir))
end

function onActivate(id)
  if id == nil or id == "" then
    return
  end
  local discordVol = string.format("%.3f", discordVolume())
  local cmd = "pw-play --target soundboard --volume " .. discordVol .. " " .. shellQuote(id)
  if alsoHeadset() then
    local headsetVol = string.format("%.3f", headsetVolume())
    cmd = cmd
      .. " & pw-play --target \"$(pactl get-default-sink)\" --volume "
      .. headsetVol
      .. " "
      .. shellQuote(id)
  end
  noctalia.runAsync(cmd)
  noctalia.notify(noctalia.tr("playing-title"), noctalia.tr("playing-body", { name = stem(id:match("([^/]+)$") or id) }))
end
