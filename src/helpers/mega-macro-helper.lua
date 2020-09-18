local macroIdDisplayNamePartLength = 8

MegaMacroScopeCodes = {
    Global = "gg",
    Class = "gc",
    Specialization = "gs",
    Character = "ch",
    CharacterSpecialization = "cs"
}

local MacroLimits = {
	Size = 1024,
	-- limit: 120 non-character specific macro slots
	GlobalCount = 70,
	PerClassCount = 25,
	PerSpecializationCount = 25,
	-- limit: 18 character specific macro slots
	PerCharacterCount = 8,
	PerCharacterSpecializationCount = 10
}

local macroStartIndexes = {
	Global = 1,
	PerClass = 1 + MacroLimits.GlobalCount,
	PerSpecialization = 1 + MacroLimits.GlobalCount + MacroLimits.PerClassCount,
	-- restarting index due to different macro scope
	PerCharacter = 1,
	PerCharacterSpecialization = 1 + MacroLimits.PerCharacterCount
}

-- Converts from a macro scope to the maximum permitted macros for that scope
local function GetMacroSlotCount(scope)
    if scope == MegaMacroScopeCodes.Global then
        return MacroLimits.GlobalCount
    elseif scope == MegaMacroScopeCodes.Class then
        return MacroLimits.PerClassCount
    elseif scope == MegaMacroScopeCodes.Specialization then
        return MacroLimits.PerSpecializationCount
    elseif scope == MegaMacroScopeCodes.Character then
        return MacroLimits.PerCharacterCount
    elseif scope == MegaMacroScopeCodes.CharacterSpecialization then
        return MacroLimits.PerCharacterSpecializationCount
    end

    return 0
end

-- Gets the scope code from the macroId
local function GetMacroScopeCode(macroId)
    return string.sub(macroId, macroIdDisplayNamePartLength + 1, 2)
end

MegaMacroHelper = {
    MaxMacroSize = MacroLimits.Size,
    HighestMaxMacroCount = max(MacroLimits.GlobalCount, MacroLimits.PerClassCount, MacroLimits.PerSpecializationCount, MacroLimits.PerCharacterCount, MacroLimits.PerCharacterSpecializationCount),
    CreateMacro = function(displayName, class, specialization, character)
        -- return macro id
    end,
    UpdateMacro = function(macroId, code)

    end,
    DeleteMacro = function(macroId)

    end,
    GetMacroSlotCount = GetMacroSlotCount,
    GetMacroScopeCode = GetMacroScopeCode
}