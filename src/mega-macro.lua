local MacroIdDisplayNamePartLength = 8

local MacroLimits = {
	-- limit: 120 non-character specific macro slots
	GlobalCount = 60,
	PerClassCount = 30,
	PerSpecializationCount = 30,
	-- limit: 18 character specific macro slots
	PerCharacterCount = 8,
	PerCharacterSpecializationCount = 10
}

local MacroStartIndexes = {
	Global = 1,
	PerClass = 1 + MacroLimits.GlobalCount,
	PerSpecialization = 1 + MacroLimits.GlobalCount + MacroLimits.PerClassCount,
	-- restarting index due to different macro scope
	PerCharacter = 1,
	PerCharacterSpecialization = 1 + MacroLimits.PerCharacterCount
}

local function RemoveItemFromArray(t, item)
    local length = #t

    for i=0, length do
        if t[i] == item then
            table.remove(t, i)
            break
        end
    end
end

local function GenerateMacroId(displayName, scope, index)
    local trimmedDisplayName = string.sub(displayName, 1, MacroIdDisplayNamePartLength)
    local trimmedLength = string.len(trimmedDisplayName)

    if trimmedLength < 8 then
        trimmedDisplayName = trimmedDisplayName .. string.rep(" ", MacroIdDisplayNamePartLength - trimmedLength)
    end

    local formattedIndex = "" .. index

    if #formattedIndex == 1 then
        formattedIndex = "0" .. formattedIndex
    end

    return trimmedDisplayName .. scope .. index
end

local function GetNextAvailableMacroIndex(start, count, existingMacros)
    for i=start, start + count - 1 do
        local isMatched = false

        for _, existingMacro in ipairs(existingMacros) do
            if existingMacro.MacroIndex == i then
                isMatched = true
                break
            end
        end

        if not isMatched then
            return i
        end
    end
end

-- Static Members
MegaMacro = {
    Scopes = {
        Global = "gg",
        Class = "gc",
        Specialization = "gs",
        Character = "ch",
        CharacterSpecialization = "cs"
    },
    CodeMaxLength = 1024,
    HighestMaxMacroCount = math.max(MacroLimits.GlobalCount, MacroLimits.PerClassCount, MacroLimits.PerSpecializationCount, MacroLimits.PerCharacterCount, MacroLimits.PerCharacterSpecializationCount),
}

function MegaMacro.Create(displayName, scope, class, specialization)
    local result = {}

    local macroIndex
    local scopedIndex
    local id
    local macroList

    if scope == MegaMacro.Scopes.Global then
        macroList = MegaMacroGlobalData.Macros
        scopedIndex = #macroList + 1

        if scopedIndex > MacroLimits.GlobalCount then
            return nil
        end

        macroIndex = GetNextAvailableMacroIndex(MacroStartIndexes.Global, MacroLimits.GlobalCount, macroList)
        id = GenerateMacroId(displayName, scope, macroIndex)
    elseif scope == MegaMacro.Scopes.Class then
        if MegaMacroGlobalData.Classes[class] == nil then
            MegaMacroGlobalData.Classes[class] = { Macros = {}, Specializations = {} }
        end

        macroList = MegaMacroGlobalData.Classes[class].Macros
        scopedIndex = #macroList + 1

        if scopedIndex > MacroLimits.PerClassCount then
            return nil
        end

        macroIndex = GetNextAvailableMacroIndex(MacroStartIndexes.PerClass, MacroLimits.PerClassCount, macroList)
        id = GenerateMacroId(displayName, scope, macroIndex)
        result.Class = class
    elseif scope == MegaMacro.Scopes.Specialization then
        if MegaMacroGlobalData.Classes[class].Specializations[specialization] == nil then
            MegaMacroGlobalData.Classes[class].Specializations[specialization] = { Macros = {} }
        end

        macroList = MegaMacroGlobalData.Classes[class].Specializations[specialization].Macros
        scopedIndex = #macroList + 1

        if scopedIndex > MacroLimits.PerSpecializationCount then
            return nil
        end

        macroIndex = GetNextAvailableMacroIndex(MacroStartIndexes.PerSpecialization, MacroLimits.PerSpecializationCount, macroList)
        id = GenerateMacroId(displayName, scope, macroIndex)
        result.Class = class
        result.Specialization = specialization
    elseif scope == MegaMacro.Scopes.Character then
        macroList = MegaMacroCharacterData.Macros
        scopedIndex = #macroList + 1

        if scopedIndex > MacroLimits.PerCharacterCount then
            return nil
        end

        macroIndex = GetNextAvailableMacroIndex(MacroStartIndexes.PerCharacter, MacroLimits.PerCharacterCount, macroList)
        id = GenerateMacroId(displayName, scope, scope)
        result.Class = class
    elseif scope == MegaMacro.Scopes.CharacterSpecialization then
        if MegaMacroCharacterData.Specializations[specialization] == nil then
            MegaMacroCharacterData.Specializations[specialization] = { Macros = {} }
        end

        macroList = MegaMacroCharacterData.Specializations[specialization].Macros
        scopedIndex = #macroList + 1

        if scopedIndex > MacroLimits.PerCharacterSpecializationCount then
            return nil
        end

        macroIndex = GetNextAvailableMacroIndex(MacroStartIndexes.PerCharacterSpecialization, MacroLimits.PerCharacterSpecializationCount, macroList)
        id = GenerateMacroId(displayName, scope, macroIndex)
        result.Class = class
        result.Specialization = specialization
    else
        return nil
    end

    table.insert(macroList, result)

    result.Id = id
    result.MacroIndex = macroIndex
    result.Scope = scope
    result.ScopedIndex = scopedIndex
    result.DisplayName = displayName
    result.Code = ""

    return result
end

function MegaMacro.GetSlotCount(scope)
    if scope == MegaMacro.Scopes.Global then
        return MacroLimits.GlobalCount
    elseif scope == MegaMacro.Scopes.Class then
        return MacroLimits.PerClassCount
    elseif scope == MegaMacro.Scopes.Specialization then
        return MacroLimits.PerSpecializationCount
    elseif scope == MegaMacro.Scopes.Character then
        return MacroLimits.PerCharacterCount
    elseif scope == MegaMacro.Scopes.CharacterSpecialization then
        return MacroLimits.PerCharacterSpecializationCount
    end

    return 0
end

function MegaMacro.Rename(self, displayName)
    local newId = GenerateMacroId(displayName, self.Scope, self.MacroIndex)
    MegaMacroIconEvaluator.ChangeMacroKey(self.Id, newId)
    self.Id = GenerateMacroId(displayName, self.Scope, self.MacroIndex)
    self.DisplayName = displayName
end

function MegaMacro.UpdateCode(self, code)
    self.Code = code
    MegaMacroCodeInfo.Clear(self.Id)
    MegaMacroIconEvaluator.UpdateMacro(self)
end

function MegaMacro.Delete(self)
    if self.Scope == MegaMacro.Scopes.Global then
        RemoveItemFromArray(MegaMacroGlobalData.Macros, self)
    elseif self.Scope == MegaMacro.Scopes.Class then
        RemoveItemFromArray(MegaMacroGlobalData.Classes[self.Class].Macros, self)
    elseif self.Scope == MegaMacro.Scopes.Specialization then
        RemoveItemFromArray(MegaMacroGlobalData.Classes[self.Class].Specializations[self.Specialization].Macros, self)
    elseif self.Scope == MegaMacro.Scopes.Character then
        RemoveItemFromArray(MegaMacroCharacterData.Macros, self)
    elseif self.Scope == MegaMacro.Scopes.CharacterSpecialization then
        RemoveItemFromArray(MegaMacroCharacterData.Specializations[self.Specialization].Macros, self)
    end

    MegaMacroCodeInfo.Clear(self.Id)
    MegaMacroIconEvaluator.RemoveMacroFromCache(self.Id)
end

function MegaMacro.GetMacrosInScope(scope)
    if scope == MegaMacro.Scopes.Global then
		return MegaMacroGlobalData.Macros
	elseif scope == MegaMacro.Scopes.Class then
        local class = UnitClass("player")
        if MegaMacroGlobalData.Classes[class] == nil then
            MegaMacroGlobalData.Classes[class] = { Macros = {}, Specializations = {} }
        end
		return MegaMacroGlobalData.Classes[class].Macros
	elseif scope == MegaMacro.Scopes.Specialization then
        local class = UnitClass("player")
        local specIndex = GetSpecialization()
        local specialization = select(2, GetSpecializationInfo(specIndex))
        if MegaMacroGlobalData.Classes[class] == nil then
            MegaMacroGlobalData.Classes[class] = { Macros = {}, Specializations = {} }
        end
        if MegaMacroGlobalData.Classes[class].Specializations[specialization] == nil then
            MegaMacroGlobalData.Classes[class].Specializations[specialization] = { Macros = {} }
        end
		return MegaMacroGlobalData.Classes[class].Specializations[specialization].Macros
	elseif scope == MegaMacro.Scopes.Character then
		return MegaMacroCharacterData.Macros
	elseif scope == MegaMacro.Scopes.CharacterSpecialization then
        local specIndex = GetSpecialization()
        local specialization = select(2, GetSpecializationInfo(specIndex))
        if MegaMacroCharacterData.Specializations[specialization] == nil then
            MegaMacroCharacterData.Specializations[specialization] = { Macros = {} }
        end
		return MegaMacroCharacterData.Specializations[specialization].Macros
    end
end