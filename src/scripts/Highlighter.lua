Highlighter = {
  config = {
    name = "Highlighter",
    package_name = "__PKGNAME__",
    package_path = getMudletHomeDir() .. "/__PKGNAME__/",
    preferences_file = "Highlighter.Preferences.lua",
  },
  default = {
    step = 10,
    delay = 0.05,
    colour = "gold",
  },
  prefs = {},
  route = {},
  event_handlers = {
    "sysLoadEvent",
    "sysUninstall",
    "sysConnectionEvent",
    "onMoveMap",
    "onSpeedwalkReset",
    "sysSpeedwalkStarted",
    "sysSpeedwalkFinished",
  },
  highlighting = false,
  highlight_colour = nil,
}

table.unpack = table.unpack or unpack

function Highlighter:Setup(event, ...)
  self:LoadPreferences()
end

function Highlighter:LoadPreferences()
  local path = self.config.package_path .. self.config.preferences_file
  local defaults = self.default
  local prefs = self.prefs

  if io.exists(path) then
    local prefs = self.default
    table.load(path, prefs)
    prefs = table.update(defaults, prefs)
  end

  self.prefs = prefs

  if not self.prefs.step then
    self.prefs.step = self.default.step
  end
  if not self.prefs.delay then
    self.prefs.delay = self.default.delay
  end
  if not self.prefs.colour then
    self.prefs.colour = self.default.colour
  end
end
function Highlighter:SavePreferences()
  local path = self.config.package_path .. self.config.preferences_file
  table.save(path, self.prefs)
end

function Highlighter:SetPreference(key, value)
  if not self.prefs then
    self.prefs = {}
  end

  if not self.default[key] then
    cecho("Unknown preference " .. key .. "\n")
    return
  end

  if key == "step" then value = tonumber(value)
  elseif key == "delay" then value = tonumber(value)
  elseif key == "colour" then
    if not color_table[value] then
      cecho("Unknown colour " .. value .. "\n")
      return
    end
  else
    cecho("Unknown preference " .. key .. "\n")
    return
  end

  self.prefs[key] = value
  self:SavePreferences()
  self:LoadPreferences()
  cecho("Preference " .. key .. " set to " .. value .. ".\n")

  self:SavePreferences()
end

-- ----------------------------------------------------------------------------
-- Event handler for all events
-- ----------------------------------------------------------------------------

-- One time install handler

registerNamedEventHandler(Highlighter.config.name, "Package Installed", "sysInstall", "Highlighter:Setup", true)

function Highlighter:SetupEventHandlers()
  -- Registered event handlers
  local registered_handlers = getNamedEventHandlers(self.config.name) or {}
  -- Register persistent event handlers
  for _, event in ipairs(self.event_handlers) do
    local handler = self.config.name .. "." .. event
    if not registered_handlers[handler] then
      local result, err = registerNamedEventHandler(self.config.name, handler, event, function(...) self:EventHandler(...) end)
      if not result then
        cecho("<orange_red>Failed to register event handler for " .. event .. "\n")
      end
    end
  end
end

Highlighter:SetupEventHandlers()

function Highlighter:EventHandler(event, ...)
  if event == "sysLoadEvent" then
    self:Setup(event, ...)
    return
  end
  if event == "sysUninstall" then
    self:Uninstall(event,...)
    return
  end
  if event == "sysConnectionEvent" then
    self:OnConnected(...)
    return
  end
  if event == "onMapMove" then
    self:OnMoved(...)
    return
  end
  if event == "onSpeedwalkReset" then
    self:OnReset(...)
    return
  end
  if event == "sysSpeedwalkStarted" then
    self:OnStarted(...)
    return
  end
  if event == "sysSpeedwalkFinished" then
    self:OnComplete(...)
    return
  end
end

-- ----------------------------------------------------------------------------
-- Event handlers for specific events
-- ----------------------------------------------------------------------------

function Highlighter:Uninstall(event, package)
  if package ~= self.config.package_name then
    return
  end

  deleteAllNamedEventHandlers(self.config.name)
  deleteAllNamedTimers(self.config.name)

  self:Reset()

  Highlighter = nil
end

function Highlighter:OnConnected(...)
  self.route = {}
end

function Highlighter:OnStarted(room_id)
  self:HighlightRoute(room_id)
  self.highlighting = true
end

function Highlighter:OnMoved(current_room_id, previous_room_id)
  if not self.highlighting or not next(self.route) then
    return
  end

  if previous_room_id then
    if self.route[previous_room_id] then
      if not self.route[previous_room_id].timer then
        self:UnhighlightRoom(previous_room_id)
      end
    end
  end

  if current_room_id then
    if not self.route[current_room_id] or (self.route[current_room_id] and not self.route[current_room_id].timer) then
      self:HighlightRoom(current_room_id)
    end
  end
end

function Highlighter:OnReset(exception, reason)
  self.highlighting = false
  self:Reset(exception)
end

function Highlighter:OnComplete(current_room_id)
  self.highlighting = false
  self:Reset(false)
end

-- ----------------------------------------------------------------------------
-- Highlighter functions
-- ----------------------------------------------------------------------------

function Highlighter:Reset(force)
  self:RemoveHighlights(force)
end

function Highlighter:HighlightRoom(room_id)
  self.highlight_colour = color_table[self.prefs.colour]
  local r, g, b = table.unpack(self.highlight_colour)

  highlightRoom(room_id, r, g, b, 0, 0, 0, 1, 125, 0)
  self.route[room_id] = {}
end

function Highlighter:HighlightRoute(start_room_id)
  if next(self.route) then
    self:RemoveHighlights(true)
  end

  self:HighlightRoom(start_room_id)
  ---@diagnostic disable-next-line: param-type-mismatch
  for i, dir in ipairs(speedWalkDir) do
    local room_id = tonumber(speedWalkPath[i])
    self:HighlightRoom(room_id)
  end
end

function Highlighter:FadeOutHighlight(room_id)
  if not self.route[room_id] then
    return
  end

  if not self.route[room_id].step then
    return
  end

  local fade_step = self.route[room_id].step + 1

  local r, g, b = table.unpack(self.highlight_colour)
  local a = 255 - fade_step * self.prefs.step

  if a <= 0 then
    unHighlightRoom(room_id)
    table.remove(self.route, room_id)
    return
  end

  highlightRoom(room_id, r, g, b, 0, 0, 0, 1, a, 0)
  self.route[room_id].timer = tempTimer(self.prefs.delay,
    function() self:FadeOutHighlight(room_id) end,
    false)
  self.route[room_id].step = fade_step
end

function Highlighter:UnhighlightRoom(room_id)
  if self.route[room_id] and self.route[room_id].timer then
    return
  end

  local r, g, b = table.unpack(self.highlight_colour)
  highlightRoom(room_id, r, g, b, 0, 0, 0, 1, 125, 0)

  self.route[room_id] = {
    step = 0,
    timer = tempTimer(0.1, function() self:FadeOutHighlight(room_id) end, false)
  }
end

function Highlighter:RemoveHighlights(force)
  if not next(self.route) then
    return
  end

  for room_id, highlight in pairs(self.route) do
    if force then
      unHighlightRoom(room_id)
      if highlight.timer then
        killTimer(highlight.timer)
      end
      table.remove(self.route, room_id)
    else
      if not highlight.timer then
        self:UnhighlightRoom(room_id)
      end
    end
  end

  if force then
    self.route = {}
  end
end
