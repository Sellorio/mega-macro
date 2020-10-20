local MacroIdDisplayNamePartLength = 8

local function RemoveItemFromArray(t, item)
    local length = #t

    for i=0, length do
        if t[i] == item then
            table.remove(t, i)
            break
        end
    end
end

local function GetNextAvailableMacroId(startOffset, count, existingMacros)
    for i=1 + startOffset, startOffset + count do
        local isMatched = false

        for _, existingMacro in ipairs(existingMacros) do
            if existingMacro.Id == i then
                isMatched = true
                break
            end
        end

        if not isMatched then
            return i
        end
    end

    return nil
end

MegaMacro = {}

function MegaMacro.Create(displayName, scope, staticTexture, isStaticTextureFallback)
    local result = {}

    local id
    local scopedIndex
    local macroList

    if scope == MegaMacroScopes.Global then
        macroList = MegaMacroGlobalData.Macros
        scopedIndex = #macroList + 1

        if scopedIndex > MacroLimits.GlobalCount then
            return nil
        end

        id = GetNextAvailableMacroId(MacroIndexOffsets.Global, MacroLimits.GlobalCount, macroList)
    elseif scope == MegaMacroScopes.Class then
        if MegaMacroGlobalData.Classes[MegaMacroCachedClass] == nil then
            MegaMacroGlobalData.Classes[MegaMacroCachedClass] = { Macros = {}, Specializations = {} }
        end

        macroList = MegaMacroGlobalData.Classes[MegaMacroCachedClass].Macros
        scopedIndex = #macroList + 1

        if scopedIndex > MacroLimits.PerClassCount then
            return nil
        end

        id = GetNextAvailableMacroId(MacroIndexOffsets.PerClass, MacroLimits.PerClassCount, macroList)
        result.Class = MegaMacroCachedClass
    elseif scope == MegaMacroScopes.Specialization then
        if MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization] == nil then
            MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization] = { Macros = {} }
        end

        macroList = MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization].Macros
        scopedIndex = #macroList + 1

        if scopedIndex > MacroLimits.PerSpecializationCount then
            return nil
        end

        id = GetNextAvailableMacroId(MacroIndexOffsets.PerSpecialization, MacroLimits.PerSpecializationCount, macroList)
        result.Class = MegaMacroCachedClass
        result.Specialization = MegaMacroCachedSpecialization
    elseif scope == MegaMacroScopes.Character then
        macroList = MegaMacroCharacterData.Macros
        scopedIndex = #macroList + 1

        if scopedIndex > MacroLimits.PerCharacterCount then
            return nil
        end

        id = GetNextAvailableMacroId(MacroIndexOffsets.PerCharacter, MacroLimits.PerCharacterCount, macroList)
        result.Class = MegaMacroCachedClass
    elseif scope == MegaMacroScopes.CharacterSpecialization then
        if MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization] == nil then
            MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization] = { Macros = {} }
        end

        macroList = MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization].Macros
        scopedIndex = #macroList + 1

        if scopedIndex > MacroLimits.PerCharacterSpecializationCount then
            return nil
        end

        id = GetNextAvailableMacroId(MacroIndexOffsets.PerCharacterSpecialization, MacroLimits.PerCharacterSpecializationCount, macroList)
        result.Class = MegaMacroCachedClass
        result.Specialization = MegaMacroCachedSpecialization
    else
        return nil
    end

    if id == nil then
        return nil
    end

    table.insert(macroList, result)

    result.Id = id
    result.Scope = scope
    result.ScopedIndex = scopedIndex
    result.DisplayName = displayName
    result.Code = ""
    result.StaticTexture = staticTexture
    result.IsStaticTextureFallback = isStaticTextureFallback

    MegaMacroEngine.OnMacroCreated(result)

    return result
end

function MegaMacro.GetSlotCount(scope)
    if scope == MegaMacroScopes.Global then
        return MacroLimits.GlobalCount
    elseif scope == MegaMacroScopes.Class then
        return MacroLimits.PerClassCount
    elseif scope == MegaMacroScopes.Specialization then
        return MacroLimits.PerSpecializationCount
    elseif scope == MegaMacroScopes.Character then
        return MacroLimits.PerCharacterCount
    elseif scope == MegaMacroScopes.CharacterSpecialization then
        return MacroLimits.PerCharacterSpecializationCount
    end

    return 0
end

function MegaMacro.GetById(macroId)
    local scope

    if not macroId then
        return nil
    elseif macroId <= MacroIndexOffsets.PerClass then
        scope = MegaMacroScopes.Global
    elseif macroId <= MacroIndexOffsets.PerSpecialization then
        scope = MegaMacroScopes.Class
    elseif macroId <= MacroIndexOffsets.PerCharacter then
        scope = MegaMacroScopes.Specialization
    elseif macroId <= MacroIndexOffsets.PerCharacterSpecialization then
        scope = MegaMacroScopes.Character
    else
        scope = MegaMacroScopes.CharacterSpecialization
    end

    local macros = MegaMacro.GetMacrosInScope(scope)
    local macroCount = #macros

    for i=1, macroCount do
        if macros[i].Id == macroId then
            return macros[i]
        end
    end

    return nil
end

function MegaMacro.UpdateDetails(self, displayName, staticTexture, isStaticTextureFallback)
    self.DisplayName = displayName
    self.StaticTexture = staticTexture
    self.IsStaticTextureFallback = isStaticTextureFallback
    MegaMacroEngine.OnMacroRenamed(self)
    MegaMacroIconEvaluator.UpdateMacro(self)
end

function MegaMacro.UpdateCode(self, code)
    self.Code = code
    MegaMacroEngine.OnMacroUpdated(self)
    MegaMacroCodeInfo.Clear(self.Id)
    MegaMacroIconEvaluator.UpdateMacro(self)
end

function MegaMacro.Delete(self)
    if self.Scope == MegaMacroScopes.Global then
        RemoveItemFromArray(MegaMacroGlobalData.Macros, self)
    elseif self.Scope == MegaMacroScopes.Class then
        RemoveItemFromArray(MegaMacroGlobalData.Classes[self.Class].Macros, self)
    elseif self.Scope == MegaMacroScopes.Specialization then
        RemoveItemFromArray(MegaMacroGlobalData.Classes[self.Class].Specializations[self.Specialization].Macros, self)
    elseif self.Scope == MegaMacroScopes.Character then
        RemoveItemFromArray(MegaMacroCharacterData.Macros, self)
    elseif self.Scope == MegaMacroScopes.CharacterSpecialization then
        RemoveItemFromArray(MegaMacroCharacterData.Specializations[self.Specialization].Macros, self)
    end

    MegaMacroEngine.OnMacroDeleted(self)
    MegaMacroCodeInfo.Clear(self.Id)
    MegaMacroIconEvaluator.RemoveMacroFromCache(self.Id)
end

function MegaMacro.Move(self, newScope)
    local newMacro = MegaMacro.Create(self.DisplayName, newScope, self.StaticTexture)
    MegaMacro.UpdateCode(newMacro, self.Code)
    MegaMacroEngine.OnMacroMoved(self, newMacro)
    MegaMacro.Delete(self)
    return newMacro
end

function MegaMacro.GetMacrosInScope(scope)
    if scope == MegaMacroScopes.Global then
		return MegaMacroGlobalData.Macros
	elseif scope == MegaMacroScopes.Class then
        if MegaMacroGlobalData.Classes[MegaMacroCachedClass] == nil then
            MegaMacroGlobalData.Classes[MegaMacroCachedClass] = { Macros = {}, Specializations = {} }
        end
		return MegaMacroGlobalData.Classes[MegaMacroCachedClass].Macros
    elseif scope == MegaMacroScopes.Specialization then
        if MegaMacroCachedSpecialization == nil then
            return {}
        end
        if MegaMacroGlobalData.Classes[MegaMacroCachedClass] == nil then
            MegaMacroGlobalData.Classes[MegaMacroCachedClass] = { Macros = {}, Specializations = {} }
        end
        if MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization] == nil then
            MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization] = { Macros = {} }
        end
		return MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization].Macros
	elseif scope == MegaMacroScopes.Character then
		return MegaMacroCharacterData.Macros
	elseif scope == MegaMacroScopes.CharacterSpecialization then
        if MegaMacroCachedSpecialization == nil then
            return {}
        end
        if MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization] == nil then
            MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization] = { Macros = {} }
        end
		return MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization].Macros
    end
end