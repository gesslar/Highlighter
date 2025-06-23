-- This is the name of this script, which may be different to the package name
-- which is why we want to have a specific identifier for events that only
-- concern this script and not the package as a whole, if it is included
-- in other packages.
local script_name = "Highlighter"

---@class Highlighter
---@field config table Configuration settings for the highlighter
---@field default table Default preference values
---@field prefs table Current user preferences
---@field route table Current route highlighting state
---@field route_fade_in table Route fade in effects
---@field route_fade_out table Route fade out effects
---@field event_handlers table[] List of event handlers to register
---@field highlighting boolean Whether highlighting is currently active
---@field highlight_colour table|nil Current highlight color
---@field previous_room_id number|nil ID of the previously highlighted room
---@field colour_table table|nil Table of environment colors
Highlighter = {
  config = {
    name = script_name,
    package_name = "__PKGNAME__",
    package_path = getMudletHomeDir() .. "/__PKGNAME__/",
    preferences_file = f[[{script_name}.Preferences.lua]],
  },
  default = {
    fade = "off",
    rollout = "on",
    step = 10,
    delay = 0.025,
    colour = "auto",
    alpha = 255,
  },
  prefs = {},
  route = {},
  route_fade_in = {},
  route_fade_out = {},
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
  colour_table = nil,
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

  if not self.prefs.rollout then
    self.prefs.rollout = self.default.rollout
  end
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
  if not self.prefs.alpha then
    self.prefs.alpha = self.default.alpha
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

  if key == "rollout" then
    if value ~= "on" and value ~= "off" then
      cecho("Unknown value for rollout " .. value .. "\n")
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
  elseif key == "rollout" then
    -- nothing to do
  elseif key == "alpha" then
    local num = tonumber(value)
    if not num or num < 0 or num > 255 then
      cecho("Alpha must be a number between 0 and 255.\n")
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
Highlighter:SetupEventHandlers()

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
  self.route_fade_in = {}
  self.route_fade_out = {}
end

function Highlighter:OnStarted()
  local room_id = getPlayerRoom()
  self.colour_table = getCustomEnvColorTable() or {}

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
  local fg, bg = self:DetermineColours(room_id)
  local alpha = self.prefs.alpha

  highlightRoom(room_id, fg[1], fg[2], fg[3], 0, 0, 0, 1, alpha, 0)
  self.route[room_id] = {}
end

function Highlighter:HighlightRoute(start_room_id)
  if next(self.route) then
    self:RemoveHighlights(true)
  end

  self.highlight_colour = color_table[self.prefs.colour]

  ---@diagnostic disable-next-line: param-type-mismatch
  for i, dir in ipairs(speedWalkDir) do
    local room_id = tonumber(speedWalkPath[i])
    if self.prefs.rollout == "on" then
      self.route[room_id] = {
        step = 0,
        direction = "in",
        timer = tempTimer((i-1)*(self.prefs.delay * 0.75), function() self:HighlightRoom(room_id) end, false)
      }
    else
      self:HighlightRoom(room_id)
    end
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

  local a = 255 - fade_step * self.prefs.step

  if a <= 0 then
    unHighlightRoom(room_id)
    killTimer(self.route[room_id].timer)
    table.remove(self.route, room_id)
    return
  end

  local fg, bg = self:DetermineColours(room_id)
  highlightRoom(room_id, fg[1], fg[2], fg[3], 0, 0, 0, 1, a, 0)

  self.route[room_id].step = fade_step
end

---@param room_id number Room ID to unhighlight
---@return nil
function Highlighter:UnhighlightRoom(room_id)
  if not self.route[room_id] then return end

  if self.prefs.fade == "off" then
    unHighlightRoom(room_id)
    return
  end

  if self.route[room_id] then
    if self.route[room_id].direction == "in" then
      killTimer(self.route[room_id].timer)
    elseif self.route[room_id].direction == "out" then
      return
    end
  end

  local fg, bg = self:DetermineColours(room_id)
  highlightRoom(room_id, fg[1], fg[2], fg[3], 0, 0, 0, 1, 125, 0)

  self.route[room_id] = {
    step = 0,
    direction = "out",
    timer = tempTimer(self.prefs.delay, function() self:FadeOutHighlight(room_id) end, true)
  }
end

---@param room_id number Room ID to determine colors for
---@return table foreground_color The adjusted foreground color
---@return table background_color The environment background color
function Highlighter:DetermineColours(room_id)
  local env = getRoomEnv(room_id)
  local bg = self.colour_table[env] or color_table.red
  local fg

  if self.prefs.colour == "auto" then
    fg = bg
  else
    ---@diagnostic disable-next-line: deprecated
    fg = color_table[self.prefs.colour]
  end

  local adjusted = self:adjust_foreground(bg, fg)

  return adjusted, bg
end

---@param force boolean|nil If true, immediately remove all highlights without fading
---@return nil
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

---@param bg table Background color as RGB table {r,g,b}
---@param fg table Foreground color as RGB table {r,g,b}
---@return table adjusted_color The adjusted foreground color for contrast
function Highlighter:adjust_foreground(bg, fg)
  local bg_is_light = self:is_light(bg)
  local fg_is_light = self:is_light(fg)

  if bg_is_light == fg_is_light then
    if bg_is_light then
      fg = self:darken_color(fg, 85)
    else
      fg = self:lighten_color(fg, 85)
    end
  end
  return fg
end

---@param color table Color as RGB table {r,g,b}
---@return boolean is_light True if the color is considered light
function Highlighter:is_light(color)
  local r = color[1] / 255
  local g = color[2] / 255
  local b = color[3] / 255
  local luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
  return luminance > 0.5
end

---@param color table Color as RGB table {r,g,b}
---@param amount? number Amount to lighten by (default: 30)
---@return table lightened_color The lightened color
function Highlighter:lighten_color(color, amount)
  amount = amount or 30
  return {
    math.min(color[1] + amount, 255),
    math.min(color[2] + amount, 255),
    math.min(color[3] + amount, 255)
  }
end

---@param color table Color as RGB table {r,g,b}
---@param amount? number Amount to darken by (default: 30)
---@return table darkened_color The darkened color
function Highlighter:darken_color(color, amount)
  amount = amount or 30
  return {
    math.max(color[1] - amount, 0),
    math.max(color[2] - amount, 0)
  }
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
    <b>rollout</b>  - Set the rollout state (<i>on</i> or <i>off</i>, default: <i>{Highlighter.default.rollout}</i>).
    <b>step</b>     - Set the granularity of the fade (default: <i>{Highlighter.default.step}</i>).
    <b>delay</b>    - Set the speed of the fade (default: <i>{Highlighter.default.delay}</i>).
    <b>colour</b>   - Set the colour of the highlight (default: <i>{Highlighter.default.colour}</i>).
]],
  }
}
