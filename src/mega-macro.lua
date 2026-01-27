local MacroIdDisplayNamePartLength = 8

-- Fixed for 12.0: Lua arrays are 1-indexed. 
-- The original 0-index loop could cause table overflows or nil errors.
local function RemoveItemFromArray(t, item)
    if not t then return end
    for i = #t, 1, -1 do
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
MegaMacro.GetNextAvailableMacroId = GetNextAvailableMacroId

function MegaMacro.Create(displayName, scope, staticTexture, isStaticTextureFallback, code, macroIndex)
    local result = {}
    local id
    local scopedIndex
    local macroList

    -- 12.0 Safety: Ensure we have character/class data before creating
    if not MegaMacroCachedClass then 
        local _, class = UnitClass("player")
        MegaMacroCachedClass = class
    end

    if scope == MegaMacroScopes.Global then
        macroList = MegaMacroGlobalData.Macros
        scopedIndex = #macroList + 1
        if scopedIndex > MacroLimits.GlobalCount then return nil end
        id = GetNextAvailableMacroId(MacroIndexOffsets.Global, MacroLimits.GlobalCount, macroList)

    elseif scope == MegaMacroScopes.Class then
        if MegaMacroGlobalData.Classes[MegaMacroCachedClass] == nil then
            MegaMacroGlobalData.Classes[MegaMacroCachedClass] = { Macros = {}, Specializations = {} }
        end
        macroList = MegaMacroGlobalData.Classes[MegaMacroCachedClass].Macros
        scopedIndex = #macroList + 1
        if scopedIndex > MacroLimits.PerClassCount then return nil end
        id = GetNextAvailableMacroId(MacroIndexOffsets.PerClass, MacroLimits.PerClassCount, macroList)
        result.Class = MegaMacroCachedClass

    elseif scope == MegaMacroScopes.Specialization then
        if not MegaMacroCachedSpecialization then return nil end -- Safety for 12.0 loading
        if MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization] == nil then
            MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization] = { Macros = {} }
        end
        macroList = MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization].Macros
        scopedIndex = #macroList + 1
        if scopedIndex > MacroLimits.PerSpecializationCount then return nil end
        id = GetNextAvailableMacroId(MacroIndexOffsets.PerSpecialization, MacroLimits.PerSpecializationCount, macroList)
        result.Class = MegaMacroCachedClass
        result.Specialization = MegaMacroCachedSpecialization

    elseif scope == MegaMacroScopes.Character then
        macroList = MegaMacroCharacterData.Macros
        scopedIndex = #macroList + 1
        if scopedIndex > MacroLimits.PerCharacterCount then return nil end
        id = GetNextAvailableMacroId(MacroIndexOffsets.PerCharacter, MacroLimits.PerCharacterCount, macroList)
        result.Class = MegaMacroCachedClass

    elseif scope == MegaMacroScopes.CharacterSpecialization then
        if not MegaMacroCachedSpecialization then return nil end
        if MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization] == nil then
            MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization] = { Macros = {} }
        end
        macroList = MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization].Macros
        scopedIndex = #macroList + 1
        if scopedIndex > MacroLimits.PerCharacterSpecializationCount then return nil end
        id = GetNextAvailableMacroId(MacroIndexOffsets.PerCharacterSpecialization, MacroLimits.PerCharacterSpecializationCount, macroList)
        result.Class = MegaMacroCachedClass
        result.Specialization = MegaMacroCachedSpecialization

    elseif scope == MegaMacroScopes.Inactive then
        macroList = MegaMacroGlobalData.InactiveMacros
        scopedIndex = #macroList + 1
        if scopedIndex > MacroLimits.InactiveCount then return nil end
        id = GetNextAvailableMacroId(MacroIndexOffsets.Inactive, MacroLimits.InactiveCount, macroList)
    else
        return nil
    end

    if id == nil then return nil end

    table.insert(macroList, result)

    result.Id = id
    result.Scope = scope
    result.ScopedIndex = scopedIndex
    result.DisplayName = displayName
    result.Code = code or ""
    result.StaticTexture = staticTexture
    result.IsStaticTextureFallback = isStaticTextureFallback

    -- Trigger the Engine to update the actual Blizzard macro
    if MegaMacroEngine and MegaMacroEngine.OnMacroCreated then
        MegaMacroEngine.OnMacroCreated(result, macroIndex)
    end

    return result
end

function MegaMacro.GetSlotCount(scope)
    if scope == MegaMacroScopes.Global then return MacroLimits.GlobalCount
    elseif scope == MegaMacroScopes.Class then return MacroLimits.PerClassCount
    elseif scope == MegaMacroScopes.Specialization then return MacroLimits.PerSpecializationCount
    elseif scope == MegaMacroScopes.Character then return MacroLimits.PerCharacterCount
    elseif scope == MegaMacroScopes.CharacterSpecialization then return MacroLimits.PerCharacterSpecializationCount
    elseif scope == MegaMacroScopes.Inactive then return MacroLimits.InactiveCount
    end
    return 0
end

function MegaMacro.GetById(macroId)
    if not macroId then return nil end
    local scope

    if macroId <= MacroIndexOffsets.PerClass then
        scope = MegaMacroScopes.Global
    elseif macroId <= MacroIndexOffsets.PerSpecialization then
        scope = MegaMacroScopes.Class
    elseif macroId <= MacroIndexOffsets.PerCharacter then
        scope = MegaMacroScopes.Specialization
    elseif macroId <= MacroIndexOffsets.PerCharacterSpecialization then
        scope = MegaMacroScopes.Character
    elseif macroId <= MacroIndexOffsets.Inactive then
        scope = MegaMacroScopes.CharacterSpecialization
    else
        scope = MegaMacroScopes.Inactive
    end

    local macros = MegaMacro.GetMacrosInScope(scope)
    if not macros then return nil end
    
    for i=1, #macros do
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
    
    if MegaMacroEngine and MegaMacroEngine.OnMacroRenamed then
        MegaMacroEngine.OnMacroRenamed(self)
    end
    
    if MegaMacroIconEvaluator then
        MegaMacroIconEvaluator.UpdateMacro(self)
    end
end

function MegaMacro.UpdateCode(self, code)
    self.Code = code
    if MegaMacroEngine and MegaMacroEngine.OnMacroUpdated then
        MegaMacroEngine.OnMacroUpdated(self)
    end
    if MegaMacroCodeInfo then MegaMacroCodeInfo.Clear(self.Id) end
    if MegaMacroIconEvaluator then MegaMacroIconEvaluator.UpdateMacro(self) end
end

function MegaMacro.Delete(self)
    -- Fixed: Added safety checks for table existence
    if self.Scope == MegaMacroScopes.Global then
        RemoveItemFromArray(MegaMacroGlobalData.Macros, self)
    elseif self.Scope == MegaMacroScopes.Class and MegaMacroGlobalData.Classes[self.Class] then
        RemoveItemFromArray(MegaMacroGlobalData.Classes[self.Class].Macros, self)
    elseif self.Scope == MegaMacroScopes.Specialization and MegaMacroGlobalData.Classes[self.Class] then
        RemoveItemFromArray(MegaMacroGlobalData.Classes[self.Class].Specializations[self.Specialization].Macros, self)
    elseif self.Scope == MegaMacroScopes.Character then
        RemoveItemFromArray(MegaMacroCharacterData.Macros, self)
    elseif self.Scope == MegaMacroScopes.CharacterSpecialization and MegaMacroCharacterData.Specializations[self.Specialization] then
        RemoveItemFromArray(MegaMacroCharacterData.Specializations[self.Specialization].Macros, self)
    elseif self.Scope == MegaMacroScopes.Inactive then
        RemoveItemFromArray(MegaMacroGlobalData.InactiveMacros, self)
    end

    if MegaMacroEngine then MegaMacroEngine.OnMacroDeleted(self) end
    if MegaMacroCodeInfo then MegaMacroCodeInfo.Clear(self.Id) end
    if MegaMacroIconEvaluator then MegaMacroIconEvaluator.RemoveMacroFromCache(self.Id) end
end

function MegaMacro.Move(self, newScope)
    local newMacro = MegaMacro.Create(self.DisplayName, newScope, self.StaticTexture)
    if newMacro then
        MegaMacro.UpdateCode(newMacro, self.Code)
        if MegaMacroEngine then MegaMacroEngine.OnMacroMoved(self, newMacro) end
        MegaMacro.Delete(self)
        return newMacro
    end
end

function MegaMacro.GetMacrosInScope(scope)
    if scope == MegaMacroScopes.Global then
        return MegaMacroGlobalData.Macros
    elseif scope == MegaMacroScopes.Class then
        if not MegaMacroCachedClass then return {} end
        if MegaMacroGlobalData.Classes[MegaMacroCachedClass] == nil then
            MegaMacroGlobalData.Classes[MegaMacroCachedClass] = { Macros = {}, Specializations = {} }
        end
        return MegaMacroGlobalData.Classes[MegaMacroCachedClass].Macros
    elseif scope == MegaMacroScopes.Specialization then
        if not MegaMacroCachedClass or not MegaMacroCachedSpecialization then return {} end
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
        if not MegaMacroCachedSpecialization then return {} end
        if MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization] == nil then
            MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization] = { Macros = {} }
        end
        return MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization].Macros
    elseif scope == MegaMacroScopes.Inactive then
        return MegaMacroGlobalData.InactiveMacros
    end
    return {}
end