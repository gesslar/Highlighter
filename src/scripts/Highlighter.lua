-- This is the name of this script, which may be different to the package name
-- which is why we want to have a specific identifier for events that only
-- concern this script and not the package as a whole, if it is included
-- in other packages.
local script_name = "Highlighter"

---@class Highlighter
---@field config table
---@field default table
---@field prefs table
---@field route table
---@field event_handlers table
---@field highlighting boolean
---@field highlight_colour nil|table
---@field previous_room_id nil|number
Highlighter = {
  config = {
    name = script_name,
    package_name = "__PKGNAME__",
    package_path = getMudletHomeDir() .. "/__PKGNAME__/",
    preferences_file = f[[{script_name}.Preferences.lua]],
  },
  default = {
    fade = "on",
    step = 10,
    delay = 0.05,
    colour = "gold",
  },
  prefs = {},
  route = {},
  event_handlers = {
    "sysUninstall",
    "sysLoadEvent",
    "sysConnectionEvent",
    "onMoveMap",
    "onSpeedwalkReset",
    "sysSpeedwalkStarted",
    "sysSpeedwalkFinished",
  },
  highlighting = false,
  highlight_colour = nil,
  previous_room_id = nil,
}

function Highlighter:Setup(event, package)
  if package and package ~= self.config.package_name then
    return
  end

  if not table.index_of(getPackages(), "Helper") then
    cecho(f "<gold><b>{self.config.name} is installing dependent <b>Helper</b> package.\n")
    installPackage(
      "https://github.com/gesslar/Helper/releases/latest/download/Helper.mpackage"
    )
  end

  self:LoadPreferences()
  self:SetupEventHandlers()

  if event == "sysInstall" then
    tempTimer(1, function()
      echo("\n")
      cecho("<" .. self.help_styles.h1 .. ">Welcome to <b>" .. self.config.name .. "</b>!<reset>\n")
      echo("\n")
      helper.print({
        text = self.help.topics.usage,
        styles = self.help_styles
      })
    end)
  end
end

function Highlighter:LoadPreferences()
  local path = self.config.package_path .. self.config.preferences_file
  local defaults = self.default
  local prefs = self.prefs or {}

  if io.exists(path) then
    local defaults = self.default
    table.load(path, prefs)
    prefs = table.update(defaults, prefs)
  end

  self.prefs = prefs

  if not self.prefs.fade then
    self.prefs.fade = self.default.fade
  end
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

  if key == "fade" then
    if value ~= "on" and value ~= "off" then
      cecho("Unknown value for fade " .. value .. "\n")
      return
    end
  end
  if key == "step" then value = tonumber(value)
  elseif key == "delay" then value = tonumber(value)
  elseif key == "colour" then
    if not color_table[value] then
      cecho("Unknown colour " .. value .. "\n")
      return
    end
  elseif key == "fade" then
    -- nothing to do
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

function Highlighter:EventHandler(event, ...)
  if event == "sysLoadEvent" or event == "sysInstall" or event == "sysConnectionEvent" then
    self:Setup(event, ...)
  elseif event == "sysUninstall" then
    self:Uninstall(event,...)
  elseif event == "sysConnectionEvent" then
    self:OnConnected(...)
  elseif event == "onMoveMap" then
    self:OnMoved(...)
  elseif event == "onSpeedwalkReset" then
    self:OnReset(...)
  elseif event == "sysSpeedwalkStarted" then
    self:OnStarted()
  elseif event == "sysSpeedwalkFinished" then
    self:OnComplete()
  end
end

registerNamedEventHandler(Highlighter.config.name, "Package Installed", "sysInstall", function(...) Highlighter:EventHandler(...) end)

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

function Highlighter:OnStarted()
  local room_id = getPlayerRoom()

  self.previous_room_id = room_id
  self.highlighting = true
  self:HighlightRoute(room_id)
end

function Highlighter:OnMoved(current_room_id)
  if not self.highlighting or not next(self.route) then
    return
  end

  if self.previous_room_id then
    if self.route[self.previous_room_id] then
      -- if not self.route[self.previous_room_id].timer then
        self:UnhighlightRoom(self.previous_room_id)
      -- end
    end
  end
  self.previous_room_id = current_room_id
end

function Highlighter:OnReset(exception, reason)
  self.highlighting = false
  self:Reset(exception)
end

function Highlighter:OnComplete()
  self.highlighting = false
  self:Reset(false)
end

-- ----------------------------------------------------------------------------
-- Highlighter functions
-- ----------------------------------------------------------------------------

function Highlighter:Reset(force)
  self:RemoveHighlights(force)
  self.previous_room_id = nil
  if force then
    self.route = {}
  end
end

function Highlighter:HighlightRoom(room_id)
  self.highlight_colour = color_table[self.prefs.colour]
  ---@diagnostic disable-next-line: deprecated
  local r, g, b = unpack(self.highlight_colour)

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

  ---@diagnostic disable-next-line: deprecated
  local r, g, b = unpack(self.highlight_colour)
  local a = 255 - fade_step * self.prefs.step

  if a <= 0 then
    unHighlightRoom(room_id)
    killTimer(self.route[room_id].timer)
    table.remove(self.route, room_id)
    return
  end

  highlightRoom(room_id, r, g, b, 0, 0, 0, 1, a, 0)
  self.route[room_id].step = fade_step
end

function Highlighter:UnhighlightRoom(room_id)
  if self.route[room_id] and self.route[room_id].timer then
    return
  end
  if self.prefs.fade == "on" then
    ---@diagnostic disable-next-line: deprecated
    local r, g, b = unpack(self.highlight_colour)
    highlightRoom(room_id, r, g, b, 0, 0, 0, 1, 125, 0)

    self.route[room_id] = {
      step = 0,
      timer = tempTimer(0.1, function() self:FadeOutHighlight(room_id) end, true)
    }
  else
    unHighlightRoom(room_id)
  end
end

function Highlighter:RemoveHighlights(force)
  if not next(self.route) then
    return
  end

  for room_id, highlight in pairs(self.route) do
    if force == true then
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

-- ----------------------------------------------------------------------------
-- Help
-- ----------------------------------------------------------------------------

Highlighter.help_styles = {
  h1 = "green_yellow",
}

Highlighter.help = {
  name = Highlighter.config.name,
  topics = {
    usage = f[[
<h1><u>{Highlighter.config.name}</u></h1>

Syntax: <b>highlight</b> [<b>command</b>]

  <b>highlight</b> - See this help text.
  <b>highlight set</b> - See your current preference settings.
  <b>highlight set</b> <<b>preference</b>> <<b>value</b>> - Set a preference to a value.

  Available preferences:
    <b>fade</b>     - Set the fade state (<i>on</i> or <i>off</i>, default: <i>{Highlighter.default.fade}</i>).
    <b>step</b>     - Set the granularity of the fade (default: <i>{Highlighter.default.step}</i>).
    <b>delay</b>    - Set the speed of the fade (default: <i>{Highlighter.default.delay}</i>).
    <b>colour</b>   - Set the colour of the highlight (default: <i>{Highlighter.default.colour}</i>).
]],
  }
}
