local input = matches[2]:trim()
local command, subcommand, value = input:match("^(%S+)%s*(%S*)%s*(.*)$")

local help = [[
Syntax: highlight [command]

  highlight set - See your current preference settings
  highlight set <preference> <value> - Set a preference to a value

  Available preferences:
    step     - Set the granularity of the fade (default: 0.0)
    delay    - Set the speed of the fade (default: 0.0)
    colour   - Set the colour of the highlight (default: gold)
]]

if command == "set" then
  if subcommand and value ~= "" then
    Highlighter:SetPreference(subcommand, value)
  else
    -- Show current preference settings
    cecho("Current preferences:\n")
    cecho("  Step: " .. Highlighter.prefs.step .. "\n")
    cecho("  Delay: " .. Highlighter.prefs.delay .. "\n")
    cecho("  Colour: " .. Highlighter.prefs.colour .. "\n")
  end
else
  -- Print out the highlighter instructions
  cecho(help)
end
