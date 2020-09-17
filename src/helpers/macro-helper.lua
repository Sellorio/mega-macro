local macroIdDisplayNamePartLength = 8

MegaMacroScopeCodes = {
    Global = "gg",
    Class = "gc",
    Specialization = "gs",
    Character = "ch",
    CharacterSpecialization = "cs"
}

MegaMacroHelper = {
    CreateMacro = function(displayName, class, specialization, character)
        -- return macro id
    end,
    UpdateMacro = function(macroId, code)

    end,
    DeleteMacro = function(macroId)

    end
}

-- Parses a macro's code to find all the conditionals that may affect it's tooltip/icon
local function ParseMacroCastConditionals(code)

end

-- Gets the scope code from the macroId
local function GetMacroScopeCode(macroId)
    return string.sub(macroId, macroIdDisplayNamePartLength + 1, 2)
end