local input = Highlighter.glu.string.trim(matches[2])
local command, subcommand, value = input:match("^(%S+)%s*(%S*)%s*(.*)$")

if command == "set" then
  if subcommand == "" then
    -- Show current preference settings
    echo(f [[ Current {Highlighter.config.name} preferences: ]] .. "\n\n")
    echo(f [[   Fade: {Highlighter.prefs.fade} ]] .. "\n")
    echo(f [[   Rollout: {Highlighter.prefs.rollout} ]] .. "\n")
    echo(f [[   Step: {Highlighter.prefs.step} ]] .. "\n")
    echo(f [[   Delay: {Highlighter.prefs.delay} ]] .. "\n")
    echo(f [[   Colour: {Highlighter.prefs.colour} ]] .. "\n")
    echo(f [[   Alpha: {Highlighter.prefs.alpha} ]] .. "\n")
  elseif value == "" then
    -- Show the one preference that was named
    if Highlighter.default[subcommand] == nil then
      cecho("Unknown preference " .. subcommand .. "\n")
    else
      echo("Preference " .. subcommand .. " is " .. Highlighter.prefs[subcommand] .. ".\n")
    end
  else
    Highlighter:SetPreference(subcommand, value)
  end
else
  -- Print out the highlighter instructions. Helper isn't there yet while it's
  -- still being installed, or if installing it failed.
  if helper then
    helper.print({ text = Highlighter.help.topics.usage, styles = Highlighter.help_styles })
  else
    cecho("<orange_red>" .. Highlighter.config.name .. " needs the Helper package to show its help.<reset>\n")
  end
end
