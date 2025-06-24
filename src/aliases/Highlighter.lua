local input = matches[2]:trim()
local command, subcommand, value = input:match("^(%S+)%s*(%S*)%s*(.*)$")

if command == "set" then
  if subcommand and value ~= "" then
    Highlighter:SetPreference(subcommand, value)
  else
    -- Show current preference settings
    echo(f[[ Current {Highlighter.config.name} preferences: ]] .. "\n\n")
    echo(f[[   Fade: {Highlighter.prefs.fade} ]] .. "\n")
    echo(f[[   Rollout: {Highlighter.prefs.rollout} ]] .. "\n")
    echo(f[[   Step: {Highlighter.prefs.step} ]] .. "\n")
    echo(f[[   Delay: {Highlighter.prefs.delay} ]] .. "\n")
    echo(f[[   Colour: {Highlighter.prefs.colour} ]] .. "\n")
    echo(f[[   Alpha: {Highlighter.prefs.alpha} ]] .. "\n")
  end
else
  -- Print out the highlighter instructions
  helper.print({ text = Highlighter.help.topics.usage, styles = Highlighter.help_styles })
end
