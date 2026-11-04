-- This is the name of this script, which may be different to the package name
-- which is why we want to have a specific identifier for events that only
-- concern this script and not the package as a whole, if it is included
-- in other packages.
local script_name = "Highlighter"
local glu_module = "__PKGNAME__/vendor/Glu-single"

-- Running this script again replaces the table below, and with it the only record
-- of what's on the map and which timers are running.
if Highlighter then Highlighter:Reset(true) end

---@class Highlighter
---@field config table Configuration settings for the highlighter
---@field default table Default preference values
---@field prefs table Current user preferences
---@field route table Current route highlighting state
---@field event_handlers string[] List of event handlers to register
---@field highlighting boolean Whether highlighting is currently active
---@field previous_room_id number|nil ID of the previously highlighted room
---@field colour_table table|nil Table of environment colors
---@field dependencies table|nil The dependency queue, while one is running
Highlighter = {
  config = {
    name = script_name,
    package_name = "__PKGNAME__",
    preferences_file = f [[{script_name}.Preferences.lua]],
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
  event_handlers = {
    "sysUninstall",
    "sysLoadEvent",
    "sysConnectionEvent",
    "onMoveMap",
    "onSpeedwalkReset",
    "sysSpeedwalkStarted",
    "sysSpeedwalkFinished",
    "sysSpeedwalkStopped",
  },
  highlighting = false,
  previous_room_id = nil,
  colour_table = nil,
  glu = require(glu_module)("__PKGNAME__"),
}

local glu = Highlighter.glu

function Highlighter:Setup(event, package)
  if package and package ~= self.config.package_name then
    return
  end

  self:LoadPreferences()

  -- sysLoadEvent can arrive while a download is under way. A second queue would
  -- install the same package again, which Mudlet refuses, and the queue would
  -- report that as a failure.
  if self.dependencies then
    return
  end

  -- Returns nil when every dependency is already installed.
  self.dependencies = glu.dependency_queue.new_dependency_queue(
    {
      {
        name = "Helper",
        url = "https://github.com/gesslar/Helper/releases/latest/download/Helper.mpackage",
      },
    },
    function(ok, message)
      self.dependencies = nil

      if not ok then
        cecho("<orange_red>" .. message .. "<reset>")
        return
      end

      if event == "sysInstall" then
        glu.func.delay(function()
          echo("\n")
          cecho("<" .. self.help_styles.h1 .. ">Welcome to <b>" .. self.config.name .. "</b>!<reset>\n")
          echo("\n")
          helper.print({
            text = self.help.topics.usage,
            styles = self.help_styles
          })
        end, 1)
      end
    end
  )

  if self.dependencies then
    self.dependencies.start()
  end
end

function Highlighter:LoadPreferences()
  -- Store prefs at the profile root (nil package) rather than inside the
  -- package directory, which Mudlet wipes on package reinstall/upgrade.
  self.prefs = glu.preferences.load(
    nil, self.config.preferences_file, self.default
  )
end

function Highlighter:SavePreferences()
  glu.preferences.save(
    nil, self.config.preferences_file, self.prefs
  )
end

function Highlighter:SetPreference(key, value)
  if not self.default[key] then
    cecho("Unknown preference " .. key .. "\n")
    return
  end

  if key == "fade" or key == "rollout" then
    if value ~= "on" and value ~= "off" then
      cecho("Unknown value for " .. key .. " " .. value .. "\n")
      return
    end
  elseif key == "step" then
    local num = tonumber(value)
    if not num or not glu.number.positive(num) then
      cecho("Step must be a positive number.\n")
      return
    end
    value = num
  elseif key == "delay" then
    local num = tonumber(value)
    -- tempTimer raises an error for anything outside this range. tonumber also
    -- accepts "nan" and "inf", which is_between turns away.
    if not num or not glu.number.is_between(num, 0, 86399) then
      cecho("Delay must be a number between 0 and 86399.\n")
      return
    end
    value = num
  elseif key == "colour" then
    -- color_table also holds "transparent", which has a fourth element that
    -- Glu's colour functions refuse.
    if value ~= "auto" and (not color_table[value] or #color_table[value] ~= 3) then
      cecho("Unknown colour " .. value .. "\n")
      return
    end
  elseif key == "alpha" then
    local num = tonumber(value)
    if not num or not glu.number.is_between(num, 0, 255) then
      cecho("Alpha must be a number between 0 and 255.\n")
      return
    end
    value = num
  end

  self.prefs[key] = value
  self:SavePreferences()
  cecho("Preference " .. key .. " set to " .. value .. ".\n")
end

-- ----------------------------------------------------------------------------
-- Event handler for all events
-- ----------------------------------------------------------------------------

function Highlighter:SetupEventHandlers()
  -- Register persistent event handlers. Registering a name again replaces its
  -- handler, which is what a re-run of this script needs: the old one is still
  -- bound to the old Highlighter table.
  for _, event in ipairs(self.event_handlers) do
    local handler = self.config.name .. "." .. event
    local result, _ = registerNamedEventHandler(self.config.name, handler, event,
      function(...) self:EventHandler(...) end)
    if not result then
      cecho("<orange_red>Failed to register event handler for " .. event .. "\n")
    end
  end
end

function Highlighter:EventHandler(event, ...)
  if event == "sysLoadEvent" or event == "sysInstall" then
    self:Setup(event, ...)
  elseif event == "sysUninstall" then
    self:Uninstall(event, ...)
  elseif event == "sysConnectionEvent" then
    self:OnConnected()
  elseif event == "onMoveMap" then
    self:OnMoved(...)
  elseif event == "onSpeedwalkReset" or event == "sysSpeedwalkStopped" then
    self:OnReset()
  elseif event == "sysSpeedwalkStarted" then
    self:OnStarted()
  elseif event == "sysSpeedwalkFinished" then
    self:OnComplete()
  end
end

registerNamedEventHandler(
  Highlighter.config.name,
  "Package Installed",
  "sysInstall",
  function(...) Highlighter:EventHandler(...) end
)

Highlighter:SetupEventHandlers()

-- No event brings the preferences in when this script is run again by hand.
Highlighter:LoadPreferences()

-- ----------------------------------------------------------------------------
-- Event handlers for specific events
-- ----------------------------------------------------------------------------

function Highlighter:Uninstall(_, package_name)
  if package_name ~= self.config.package_name then
    return
  end

  deleteAllNamedEventHandlers(self.config.name)

  -- Forced, as nothing would be left to clear the map or stop a timer later.
  self:Reset(true)

  -- Mudlet keeps this cached after an uninstall, so upgrading in the same
  -- session would otherwise run the new script against the old Glu.
  package.loaded[glu_module] = nil

  cecho("<" .. self.help_styles.h1 .. ">[" .. self.config.name .. "]<reset> You have uninstalled " .. self.config.name .. ".\n")

  ---@diagnostic disable-next-line: assign-type-mismatch
  Highlighter = nil
end

function Highlighter:OnConnected()
  self:OnReset()
end

function Highlighter:OnStarted()
  local room_id = getPlayerRoom()

  -- getCustomEnvColorTable() returns {r, g, b, a} (Mudlet appends alpha),
  -- but Glu's colour functions require exactly {r, g, b}. Strip the alpha.
  self.colour_table = glu.table.map(getCustomEnvColorTable() or {}, function(_, rgb)
    return glu.table.slice(rgb, 1, 3)
  end)

  self.previous_room_id = room_id
  self.highlighting = true
  self:HighlightRoute()
end

function Highlighter:OnMoved(current_room_id)
  if not self.highlighting or not next(self.route) then
    return
  end

  -- Mappers can raise this for any room update, not just a move, and the room
  -- the player is still standing in keeps its highlight.
  if current_room_id == self.previous_room_id then
    return
  end

  if self.previous_room_id then
    self:UnhighlightRoom(self.previous_room_id)
  end
  self.previous_room_id = current_room_id
end

-- onSpeedwalkReset's exception says why the walk ended. That has no bearing on
-- how the highlights go, which is always straight away.
function Highlighter:OnReset()
  self.highlighting = false
  self:Reset(true)
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
end

function Highlighter:HighlightRoom(room_id)
  local fg, _ = self:DetermineColours(room_id)

  highlightRoom(room_id, fg[1], fg[2], fg[3], 0, 0, 0, 1, self.prefs.alpha, 0)
  self.route[room_id] = {}
end

function Highlighter:HighlightRoute()
  self:RemoveHighlights(true)

  -- speedWalkPath doesn't exist until Mudlet has worked out a path, and
  -- speedwalk() raises sysSpeedwalkStarted without needing one.
  ---@diagnostic disable-next-line: param-type-mismatch
  for i, room in ipairs(speedWalkPath or {}) do
    local room_id = tonumber(room) --[[@as number]]

    if self.prefs.rollout == "on" then
      self.route[room_id] = {
        step = 0,
        direction = "in",
        timer = glu.func.delay(function() self:HighlightRoom(room_id) end, (i - 1) * (self.prefs.delay * 0.75))
      }
    else
      self:HighlightRoom(room_id)
    end
  end
end

function Highlighter:FadeOutHighlight(room_id)
  local highlight = self.route[room_id]

  if not highlight then
    return
  end

  local fade_step = highlight.step + 1

  local a = highlight.alpha - fade_step * self.prefs.step

  if a <= 0 then
    unHighlightRoom(room_id)
    killTimer(highlight.timer)
    self.route[room_id] = nil
    return
  end

  local fg = highlight.fg
  highlightRoom(room_id, fg[1], fg[2], fg[3], 0, 0, 0, 1, a, 0)

  highlight.step = fade_step
end

---@param room_id number Room ID to unhighlight
---@return nil
function Highlighter:UnhighlightRoom(room_id)
  local highlight = self.route[room_id]

  if not highlight or highlight.direction == "out" then
    return
  end

  -- Still waiting to roll out, so it isn't on the map yet. Left alone, its timer
  -- would draw it after we've moved on.
  local waiting = highlight.direction == "in"

  if waiting and highlight.timer then
    killTimer(highlight.timer)
  end

  if self.prefs.fade == "off" then
    if not waiting then
      unHighlightRoom(room_id)
    end
    self.route[room_id] = nil
    return
  end

  local fg, _ = self:DetermineColours(room_id)

  -- Drop to half straight away, which is what leaves a trail behind the player,
  -- and fade out from there.
  local alpha = math.floor(self.prefs.alpha / 2)
  highlightRoom(room_id, fg[1], fg[2], fg[3], 0, 0, 0, 1, alpha, 0)

  self.route[room_id] = {
    step = 0,
    direction = "out",
    fg = fg,
    alpha = alpha,
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
  for room_id, highlight in pairs(self.route) do
    if force then
      unHighlightRoom(room_id)
      if highlight.timer then
        killTimer(highlight.timer)
      end
    else
      self:UnhighlightRoom(room_id)
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
  return glu.colour.lighten_or_darken(fg, bg, 85)
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
    usage = f [[
<h1><u>{Highlighter.config.name}</u></h1>

Syntax: <b>highlight</b> [<b>command</b>]

  <b>highlight</b> - See this help text.
  <b>highlight set</b> - See your current preference settings.
  <b>highlight set</b> <<b>preference</b>> - See the current value of a preference.
  <b>highlight set</b> <<b>preference</b>> <<b>value</b>> - Set a preference to a value.

  Available preferences:
    <b>fade</b>     - Set the fade state (<i>on</i> or <i>off</i>, default: <i>{Highlighter.default.fade}</i>).
    <b>rollout</b>  - Set the rollout state (<i>on</i> or <i>off</i>, default: <i>{Highlighter.default.rollout}</i>).
    <b>step</b>     - Set the granularity of the fade (default: <i>{Highlighter.default.step}</i>).
    <b>delay</b>    - Set the speed of the fade (default: <i>{Highlighter.default.delay}</i>).
    <b>colour</b>   - Set the colour of the highlight (<i>auto</i> or a named colour, default: <i>{Highlighter.default.colour}</i>).
    <b>alpha</b>    - Set the opacity of the highlight (<i>0</i>-<i>255</i>, default: <i>{Highlighter.default.alpha}</i>).
]],
  }
}
