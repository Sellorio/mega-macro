local Commands = {}
for globalName, command in pairs(_G) do
    if string.sub(globalName, 1, 6) == "SLASH_" then
        table.insert(Commands, string.sub(command, 2))
    end
end

MegaMacroParser = {}

function MegaMacroParser.Parse(code)
end