-- Runs inside real Mudlet with the built package installed, so the alias, events,
-- timers, colour tables and map API are the real ones. highlightRoom and
-- unHighlightRoom still run, and are wrapped so that specs can see what was drawn.
--
-- Busted runs specs in a sandboxed environment, so a global that Highlighter has
-- to see must be assigned through _G.
describe("Highlighter", function()
  local GLU_MODULE = "Highlighter/vendor/Glu-single"

  local saved = {}
  local printed, helped, draws, lit, downloads
  local area_id, rooms
  local player_room

  -- Replace a global for the length of one spec. Boxed, so that a global which
  -- was nil to begin with goes back to being nil.
  local function shim(name, value)
    if not saved[name] then saved[name] = { _G[name] } end
    _G[name] = value
  end

  local function output()
    return table.concat(printed)
  end

  local function room()
    local id = createRoomID()
    addRoom(id)
    setRoomArea(id, area_id)
    setRoomCoordinates(id, id, 0, 0)
    rooms[#rooms + 1] = id
    return id
  end

  local function make_rooms(count)
    local made = {}
    for i = 1, count do made[i] = room() end
    return made
  end

  local function prefs(values)
    for key, value in pairs(values) do
      Highlighter.prefs[key] = value
    end
  end

  local function set_path(ids)
    local path, dirs = {}, {}
    for i, id in ipairs(ids) do
      path[i] = tostring(id)
      dirs[i] = "north"
    end
    _G.speedWalkPath, _G.speedWalkDir = path, dirs
  end

  local function walk(ids)
    set_path(ids)
    raiseEvent("sysSpeedwalkStarted")
  end

  local function lit_count()
    local count = 0
    for _ in pairs(lit) do count = count + 1 end
    return count
  end

  local function draws_of(id)
    local found = {}
    for _, draw in ipairs(draws) do
      if draw.id == id then found[#found + 1] = draw end
    end
    return found
  end

  -- Let timers fire.
  local function pump(ms)
    pumpEvents(ms or 300)
  end

  -- Nothing may still be drawing once the timers have had their chance.
  local function assert_settled()
    pump()
    local count = #draws
    pump()
    assert.are.equal(count, #draws)
  end

  before_each(function()
    printed, helped, draws, lit, downloads, rooms = {}, {}, {}, {}, {}, {}
    player_room = nil

    local highlight, unhighlight = _G.highlightRoom, _G.unHighlightRoom

    shim("highlightRoom", function(id, r, g, b, r2, g2, b2, radius, a1, a2)
      draws[#draws + 1] = { id = id, rgb = { r, g, b }, alpha = a1 }
      lit[id] = true
      return highlight(id, r, g, b, r2, g2, b2, radius, a1, a2)
    end)
    shim("unHighlightRoom", function(id)
      lit[id] = nil
      return unhighlight(id)
    end)
    shim("getPlayerRoom", function() return player_room end)
    shim("echo", function(text) printed[#printed + 1] = text end)
    shim("cecho", function(text) printed[#printed + 1] = text end)
    shim("helper", { print = function(options) helped[#helped + 1] = options end })
    -- Helper counts as installed unless a spec says otherwise.
    shim("getPackages", function() return { "Helper" } end)
    shim("downloadFile", function(target, url)
      downloads[#downloads + 1] = { target = target, url = url }
      return true
    end)

    area_id = addAreaName("HighlighterTest" .. getEpoch())

    os.remove(getMudletHomeDir() .. "/" .. Highlighter.config.preferences_file)
    Highlighter:LoadPreferences()
    Highlighter:OnReset()
    Highlighter.dependencies = nil
    Highlighter.colour_table = {}

    prefs({ rollout = "off", fade = "off", delay = 0.01, step = 50 })
  end)

  after_each(function()
    Highlighter:OnReset()

    for name, box in pairs(saved) do _G[name] = box[1] end
    saved = {}
    _G.speedWalkPath, _G.speedWalkDir = nil, nil

    for _, id in ipairs(rooms) do deleteRoom(id) end
    deleteArea(area_id)
    os.remove(getMudletHomeDir() .. "/" .. Highlighter.config.preferences_file)
  end)

  describe("the highlight alias", function()
    it("should show the help for a bare highlight", function()
      expandAlias("highlight", false)
      assert.are.equal(1, #helped)
    end)

    it("should leave other commands starting with highlight alone", function()
      expandAlias("highlights", false)
      expandAlias("highlighter", false)
      assert.are.equal(0, #helped)
    end)

    it("should say so when Helper isn't there to show the help", function()
      shim("helper", nil)
      expandAlias("highlight", false)
      assert.is_truthy(output():find("needs the Helper package", 1, true))
    end)

    it("should list every preference for set", function()
      expandAlias("highlight set", false)
      assert.is_truthy(output():find("Fade:", 1, true))
      assert.is_truthy(output():find("Alpha:", 1, true))
    end)

    it("should show only the named preference for set with no value", function()
      prefs({ step = 7 })
      expandAlias("highlight set step", false)
      assert.is_truthy(output():find("Preference step is 7.", 1, true))
      assert.is_nil(output():find("Alpha:", 1, true))
    end)

    it("should turn away an unknown preference with no value", function()
      expandAlias("highlight set bogus", false)
      assert.is_truthy(output():find("Unknown preference bogus", 1, true))
    end)

    it("should set a preference", function()
      expandAlias("highlight set step 7", false)
      assert.are.equal(7, Highlighter.prefs.step)
    end)
  end)

  describe("preferences", function()
    it("should come back the same after being saved", function()
      Highlighter:SetPreference("fade", "on")
      Highlighter:SetPreference("step", "5")
      Highlighter:LoadPreferences()
      assert.are.equal("on", Highlighter.prefs.fade)
      assert.are.equal(5, Highlighter.prefs.step)
    end)

    it("should turn away an unknown preference", function()
      Highlighter:SetPreference("bogus", "1")
      assert.is_nil(Highlighter.prefs.bogus)
    end)

    it("should only take on or off for fade and rollout", function()
      Highlighter:SetPreference("fade", "maybe")
      Highlighter:SetPreference("rollout", "maybe")
      assert.are.equal("off", Highlighter.prefs.fade)
      assert.are.equal("off", Highlighter.prefs.rollout)
    end)

    it("should only take a positive step", function()
      Highlighter:SetPreference("step", "0")
      Highlighter:SetPreference("step", "-1")
      Highlighter:SetPreference("step", "abc")
      assert.are.equal(50, Highlighter.prefs.step)
    end)

    it("should turn away a delay that tempTimer would refuse", function()
      for _, bad in ipairs({ "nan", "inf", "-inf", "100000", "-1", "abc" }) do
        Highlighter:SetPreference("delay", bad)
        assert.are.equal(0.01, Highlighter.prefs.delay)
      end
    end)

    it("should take a delay of zero", function()
      Highlighter:SetPreference("delay", "0")
      assert.are.equal(0, Highlighter.prefs.delay)
    end)

    it("should keep alpha between 0 and 255", function()
      Highlighter:SetPreference("alpha", "300")
      Highlighter:SetPreference("alpha", "-1")
      assert.are.equal(255, Highlighter.prefs.alpha)
      Highlighter:SetPreference("alpha", "0")
      assert.are.equal(0, Highlighter.prefs.alpha)
    end)

    it("should turn away transparent, which Glu's colour functions refuse", function()
      Highlighter:SetPreference("colour", "transparent")
      assert.are.equal("auto", Highlighter.prefs.colour)
    end)

    it("should take a named colour and turn away a made up one", function()
      Highlighter:SetPreference("colour", "gold")
      assert.are.equal("gold", Highlighter.prefs.colour)
      Highlighter:SetPreference("colour", "nonsense")
      assert.are.equal("gold", Highlighter.prefs.colour)
    end)
  end)

  describe("colours", function()
    it("should draw from the room's custom environment colour", function()
      local id = room()
      setCustomEnvColor(300, 10, 20, 200, 255)
      setRoomEnv(id, 300)

      walk({ id })

      local colour = { 10, 20, 200 }
      assert.are.same(
        Highlighter.glu.colour.lighten_or_darken(colour, colour, 85),
        draws_of(id)[1].rgb
      )
    end)

    it("should fall back on red for a room with no custom colour", function()
      local id = room()

      walk({ id })

      local red = color_table.red
      assert.are.same(
        Highlighter.glu.colour.lighten_or_darken(red, red, 85),
        draws_of(id)[1].rgb
      )
    end)

    it("should draw from a named colour when one is set", function()
      local id = room()
      prefs({ colour = "gold" })

      walk({ id })

      assert.are.same(
        Highlighter.glu.colour.lighten_or_darken(color_table.gold, color_table.red, 85),
        draws_of(id)[1].rgb
      )
    end)
  end)

  describe("a walk", function()
    it("should light the whole path at once with rollout off", function()
      local ids = make_rooms(3)
      walk(ids)
      assert.are.equal(3, lit_count())
    end)

    it("should light the path over time with rollout on", function()
      local ids = make_rooms(3)
      prefs({ rollout = "on" })

      walk(ids)
      assert.are.equal(0, lit_count())

      pump()
      assert.are.equal(3, lit_count())
    end)

    it("should cope with no path having been worked out", function()
      _G.speedWalkPath, _G.speedWalkDir = nil, nil
      raiseEvent("sysSpeedwalkStarted")
      raiseEvent("sysSpeedwalkFinished")
      assert.are.equal(0, lit_count())
    end)

    it("should take the highlight off each room left behind", function()
      local ids = make_rooms(3)
      walk(ids)

      raiseEvent("onMoveMap", ids[1])
      raiseEvent("onMoveMap", ids[2])

      assert.is_nil(lit[ids[1]])
      assert.is_true(lit[ids[2]])
      assert.is_true(lit[ids[3]])
    end)

    it("should keep the highlight when the same room is updated again", function()
      local ids = make_rooms(2)
      walk(ids)

      raiseEvent("onMoveMap", ids[1])
      raiseEvent("onMoveMap", ids[1])

      assert.is_true(lit[ids[1]])
    end)

    it("should never draw a room already passed while rolling out", function()
      local ids = make_rooms(4)
      prefs({ rollout = "on", delay = 0.05 })

      walk(ids)
      raiseEvent("onMoveMap", ids[3])
      raiseEvent("onMoveMap", ids[4])
      pump()

      assert.are.equal(0, #draws_of(ids[3]))
    end)

    it("should leave nothing lit when it ends during the rollout", function()
      local ids = make_rooms(4)
      prefs({ rollout = "on", delay = 0.05 })

      walk(ids)
      raiseEvent("sysSpeedwalkFinished", false, "Arrived at destination.")
      assert_settled()

      assert.are.equal(0, lit_count())
      assert.is_nil(next(Highlighter.route))
    end)

    it("should drain completely when it finishes with fade off", function()
      local ids = make_rooms(3)
      prefs({ rollout = "on" })

      walk(ids)
      pump()
      raiseEvent("onMoveMap", ids[1])
      raiseEvent("onMoveMap", ids[2])
      raiseEvent("sysSpeedwalkFinished")
      assert_settled()

      assert.are.equal(0, lit_count())
      assert.is_nil(next(Highlighter.route))
      assert.is_false(Highlighter.highlighting)
    end)

    it("should drain completely when it finishes with fade on", function()
      local ids = make_rooms(3)
      prefs({ fade = "on" })

      walk(ids)
      raiseEvent("onMoveMap", ids[1])
      raiseEvent("sysSpeedwalkFinished")
      assert_settled()

      assert.are.equal(0, lit_count())
      assert.is_nil(next(Highlighter.route))
    end)

    it("should replace an old route that is still fading", function()
      local old, new = make_rooms(2), make_rooms(2)
      prefs({ fade = "on", delay = 0.05 })

      walk(old)
      raiseEvent("sysSpeedwalkFinished")
      pump(60)
      walk(new)

      assert.is_nil(lit[old[1]])
      assert.is_nil(lit[old[2]])
      assert.is_true(lit[new[1]])
      assert.is_true(lit[new[2]])

      local count = #draws_of(old[1])
      pump()
      assert.are.equal(count, #draws_of(old[1]))
    end)
  end)

  describe("fading", function()
    local function fade_alphas(alpha, step)
      local ids = make_rooms(2)
      prefs({ fade = "on", alpha = alpha, step = step })

      walk(ids)
      raiseEvent("onMoveMap", ids[1])
      raiseEvent("onMoveMap", ids[2])
      assert_settled()

      assert.is_nil(lit[ids[1]])

      local alphas = {}
      for i, draw in ipairs(draws_of(ids[1])) do alphas[i] = draw.alpha end
      return alphas
    end

    it("should drop to half the alpha preference on leaving", function()
      assert.are.same({ 100, 50 }, fade_alphas(100, 50))
    end)

    it("should fade out from there without brightening", function()
      assert.are.same({ 255, 127, 77, 27 }, fade_alphas(255, 50))
    end)

    it("should dim a room the moment the player leaves it", function()
      local ids = make_rooms(2)
      prefs({ fade = "on", alpha = 200 })

      walk(ids)
      raiseEvent("onMoveMap", ids[1])
      raiseEvent("onMoveMap", ids[2])

      local room_draws = draws_of(ids[1])
      assert.are.equal(100, room_draws[#room_draws].alpha)
      assert.is_true(lit[ids[1]])
    end)

    it("should still trail a room passed before it rolled out", function()
      local ids = make_rooms(4)
      prefs({ rollout = "on", fade = "on", delay = 0.05 })

      walk(ids)
      raiseEvent("onMoveMap", ids[3])
      raiseEvent("onMoveMap", ids[4])

      assert.are.equal(127, draws_of(ids[3])[1].alpha)
      assert_settled()
      assert.is_nil(lit[ids[3]])
    end)
  end)

  describe("onSpeedwalkReset", function()
    local function assert_cleared_by(...)
      local ids = make_rooms(3)
      prefs({ fade = "on" })

      walk(ids)
      raiseEvent("onSpeedwalkReset", ...)

      assert.are.equal(0, lit_count())
      assert.is_nil(next(Highlighter.route))
      assert_settled()
      assert.are.equal(0, lit_count())
    end

    it("should clear at once for Carto's call", function()
      assert_cleared_by(true, "You have veered off the expected path.")
    end)

    it("should clear at once when exception is false", function()
      assert_cleared_by(false, "reset")
    end)

    it("should clear at once with no arguments", function()
      assert_cleared_by()
    end)

    it("should clear at once for a truthy non-boolean", function()
      assert_cleared_by("yes", "reset")
    end)
  end)

  describe("sysSpeedwalkStopped", function()
    local function assert_cleared_by(...)
      local ids = make_rooms(3)
      prefs({ fade = "on" })

      walk(ids)
      raiseEvent("onMoveMap", ids[1])
      raiseEvent("onMoveMap", ids[2])
      raiseEvent("sysSpeedwalkStopped", ...)

      assert.are.equal(0, lit_count())
      assert.is_nil(next(Highlighter.route))
      assert.is_false(Highlighter.highlighting)
      assert_settled()
      assert.are.equal(0, lit_count())
    end

    it("should clear at once for Carto's walk stop", function()
      assert_cleared_by(false, "User stopped the walk")
    end)

    it("should clear at once for Mudlet's stopSpeedwalk, with no arguments", function()
      assert_cleared_by()
    end)
  end)

  describe("reconnecting", function()
    it("should clear the map and stop any fade", function()
      local ids = make_rooms(3)
      prefs({ fade = "on" })

      walk(ids)
      raiseEvent("onMoveMap", ids[1])
      raiseEvent("onMoveMap", ids[2])
      raiseEvent("sysConnectionEvent")

      assert.are.equal(0, lit_count())
      assert.is_false(Highlighter.highlighting)
      assert_settled()
    end)

    it("should not run Setup again", function()
      -- With Helper missing, Setup would start downloading it.
      shim("getPackages", function() return {} end)

      raiseEvent("sysConnectionEvent")

      assert.are.equal(0, #downloads)
    end)
  end)

  describe("the Helper dependency", function()
    -- The test profile has a sysLoadEvent of its own, so this goes straight to
    -- the handler rather than raising the event.
    local function load_event()
      Highlighter:EventHandler("sysLoadEvent")
    end

    before_each(function()
      shim("getPackages", function() return {} end)
    end)

    it("should only download once with one already under way", function()
      load_event()
      load_event()
      assert.are.equal(1, #downloads)

      raiseEvent("sysDownloadError", "offline", downloads[1].target)
    end)

    it("should report a failure and try again on the next load", function()
      load_event()
      raiseEvent("sysDownloadError", "offline", downloads[1].target)

      assert.is_truthy(output():find("Failed to download", 1, true))
      assert.is_nil(Highlighter.dependencies)

      load_event()
      assert.are.equal(2, #downloads)

      raiseEvent("sysDownloadError", "offline", downloads[2].target)
    end)

    it("should show no welcome when the install fails", function()
      Highlighter:Setup("sysInstall", Highlighter.config.package_name)
      raiseEvent("sysDownloadError", "offline", downloads[1].target)

      pump(1100)
      assert.are.equal(0, #helped)
    end)

    it("should ignore another package's events", function()
      Highlighter:Setup("sysInstall", "SomethingElse")
      assert.are.equal(0, #downloads)
    end)

    it("should welcome on install once Helper is there", function()
      shim("getPackages", function() return { "Helper" } end)

      Highlighter:Setup("sysInstall", Highlighter.config.package_name)
      assert.are.equal(0, #downloads)

      pump(1100)
      assert.is_truthy(output():find("Welcome to", 1, true))
      assert.are.equal(1, #helped)
    end)
  end)

  describe("uninstalling", function()
    local instance, glu_module

    -- Straight to the handler, as raising sysUninstall would also make the Glu
    -- instance clean itself up, and the other specs still need it.
    local function uninstall()
      instance:EventHandler("sysUninstall", instance.config.package_name)
    end

    before_each(function()
      instance = Highlighter
      glu_module = package.loaded[GLU_MODULE]
    end)

    -- Uninstalling takes everything with it, and the other specs still need it.
    after_each(function()
      _G.Highlighter = instance
      package.loaded[GLU_MODULE] = glu_module
      instance:SetupEventHandlers()
    end)

    it("should clear the map, stop every timer and remove itself", function()
      local ids = make_rooms(3)
      instance.prefs.fade = "on"

      walk(ids)
      raiseEvent("onMoveMap", ids[1])
      raiseEvent("onMoveMap", ids[2])
      uninstall()

      assert.is_nil(_G.Highlighter)
      assert.are.equal(0, lit_count())
      assert_settled()
    end)

    it("should drop the cached Glu so an upgrade loads the new one", function()
      assert.is_truthy(glu_module)
      uninstall()
      assert.is_nil(package.loaded[GLU_MODULE])
    end)

    it("should say it has been uninstalled", function()
      uninstall()
      assert.is_truthy(output():find("You have uninstalled Highlighter.", 1, true))
    end)

    it("should ignore another package being uninstalled", function()
      raiseEvent("sysUninstall", "SomethingElse")
      assert.are.equal(instance, _G.Highlighter)
      assert.is_nil(output():find("You have uninstalled", 1, true))
    end)
  end)
end)
