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

-- IDs that already have a game macro come first, since the others need room in the game's macro list
local function GetNextAvailableMacroId(startOffset, count, existingMacros)
    local firstFree

    for i=1 + startOffset, startOffset + count do
        local isMatched = false

        for _, existingMacro in ipairs(existingMacros) do
            if existingMacro.Id == i then
                isMatched = true
                break
            end
        end

        if not isMatched and MegaMacroEngine.IsIdHeldByUnknownMacro(i) then
            isMatched = true
        end

        if not isMatched then
            if MegaMacroEngine.GetMacroIndexFromId(i) then
                return i
            end

            firstFree = firstFree or i
        end
    end

    return firstFree
end

MegaMacro = {}
MegaMacro.GetNextAvailableMacroId = GetNextAvailableMacroId

local function GetIdRange(scope)
    if scope == MegaMacroScopes.Global then
        return MacroIndexOffsets.Global, MacroLimits.GlobalCount
    elseif scope == MegaMacroScopes.Class then
        return MacroIndexOffsets.PerClass, MacroLimits.PerClassCount
    elseif scope == MegaMacroScopes.Specialization then
        return MacroIndexOffsets.PerSpecialization, MacroLimits.PerSpecializationCount
    elseif scope == MegaMacroScopes.Character then
        return MacroIndexOffsets.PerCharacter, MacroLimits.PerCharacterCount
    elseif scope == MegaMacroScopes.CharacterSpecialization then
        return MacroIndexOffsets.PerCharacterSpecialization, MacroLimits.PerCharacterSpecializationCount
    elseif scope == MegaMacroScopes.Inactive then
        return MacroIndexOffsets.Inactive, MacroLimits.InactiveCount
    end
end

MegaMacro.GetIdRange = GetIdRange

-- True if a macro in this scope could take this ID: it's in the scope's range and no saved macro uses it
function MegaMacro.CanUseId(scope, macroId)
    local offset, count = GetIdRange(scope)
    return offset and macroId and macroId > offset and macroId <= offset + count and not MegaMacro.IsKnownId(macroId) or false
end

-- The ID the next macro created in this scope will get
function MegaMacro.GetNextIdInScope(scope)
    local offset, count = GetIdRange(scope)
    return offset and GetNextAvailableMacroId(offset, count, MegaMacro.GetMacrosInScope(scope))
end

-- On Forever the class tab also holds the spec list (see MegaMacroSharedSpecialization).
-- Every other tab is just its own scope. The Inactive tab's scope is nil, so it can't go in a list.
local MergedTabScopes = { MegaMacroScopes.Class, MegaMacroScopes.Specialization }

local function IsMergedTab(scope)
    return MegaMacroIsForever and scope == MegaMacroScopes.Class
end

-- The scopes the tab shows when it has more than one, otherwise nothing
function MegaMacro.GetMergedTabScopes(tabScope)
    return IsMergedTab(tabScope) and MergedTabScopes or nil
end

function MegaMacro.IsOnTab(macro, tabScope)
    if IsMergedTab(tabScope) then
        return macro.Scope == MegaMacroScopes.Class or macro.Scope == MegaMacroScopes.Specialization
    end

    return macro.Scope == tabScope
end

-- A new list for the merged tab, otherwise the saved list itself
function MegaMacro.GetMacrosOnTab(tabScope)
    if not IsMergedTab(tabScope) then
        return MegaMacro.GetMacrosInScope(tabScope)
    end

    local result = {}

    for _, scope in ipairs(MergedTabScopes) do
        for _, macro in ipairs(MegaMacro.GetMacrosInScope(scope)) do
            table.insert(result, macro)
        end
    end

    return result
end

function MegaMacro.GetTabSlotCount(tabScope)
    if not IsMergedTab(tabScope) then
        return MegaMacro.GetSlotCount(tabScope)
    end

    local count = 0

    for _, scope in ipairs(MergedTabScopes) do
        count = count + MegaMacro.GetSlotCount(scope)
    end

    return count
end

-- preferredId is used instead of the next free ID when the scope can take it
local function CreateInScope(displayName, scope, staticTexture, isStaticTextureFallback, code, macroIndex, preferredId)
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
    elseif scope == MegaMacroScopes.Inactive then
        macroList = MegaMacroGlobalData.InactiveMacros
        scopedIndex = #macroList + 1

        if scopedIndex > MacroLimits.InactiveCount then
            return nil
        end

        id = GetNextAvailableMacroId(MacroIndexOffsets.Inactive, MacroLimits.InactiveCount, macroList)
    else
        return nil
    end

    if preferredId and MegaMacro.CanUseId(scope, preferredId) then
        id = preferredId
    elseif not macroIndex and scope ~= MegaMacroScopes.Inactive and MegaMacroEngine.GetAvailableSlotCount(scope) == 0 then
        -- No ID or game macro is free for it, so it would be saved but never work
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
    result.Code = code or ""
    result.StaticTexture = staticTexture
    result.IsStaticTextureFallback = isStaticTextureFallback

    MegaMacroEngine.OnMacroCreated(result, macroIndex)

    return result
end

-- Creates the macro in exactly this scope
MegaMacro.CreateInScope = CreateInScope

-- Creates the macro on the tab for this scope. A tab with more than one scope fills them in order,
-- except that a preferred ID picks the scope it belongs to.
function MegaMacro.Create(displayName, scope, staticTexture, isStaticTextureFallback, code, macroIndex, preferredId)
    if not IsMergedTab(scope) then
        return CreateInScope(displayName, scope, staticTexture, isStaticTextureFallback, code, macroIndex, preferredId)
    end

    local scopes = MergedTabScopes

    if preferredId and MegaMacro.CanUseId(scopes[2], preferredId) then
        scopes = { scopes[2], scopes[1] }
    end

    for _, tabScope in ipairs(scopes) do
        local macro = CreateInScope(displayName, tabScope, staticTexture, isStaticTextureFallback, code, macroIndex, preferredId)

        if macro then
            return macro
        end
    end

    return nil
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
    elseif scope == MegaMacroScopes.Inactive then
        return MacroLimits.InactiveCount
    end

    return 0
end

-- True if saved data for this character uses the ID in any scope, including other classes and specializations
function MegaMacro.IsKnownId(macroId)
    local function HasId(macroList)
        for _, macro in ipairs(macroList or {}) do
            if macro.Id == macroId then
                return true
            end
        end

        return false
    end

    if HasId(MegaMacroGlobalData.Macros) or HasId(MegaMacroGlobalData.InactiveMacros) or HasId(MegaMacroCharacterData.Macros) then
        return true
    end

    for _, classData in pairs(MegaMacroGlobalData.Classes) do
        if HasId(classData.Macros) then
            return true
        end

        for _, specializationData in pairs(classData.Specializations) do
            if HasId(specializationData.Macros) then
                return true
            end
        end
    end

    for _, specializationData in pairs(MegaMacroCharacterData.Specializations) do
        if HasId(specializationData.Macros) then
            return true
        end
    end

    return false
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
    elseif macroId <= MacroIndexOffsets.Inactive then
        scope = MegaMacroScopes.CharacterSpecialization
    else
        scope = MegaMacroScopes.Inactive
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
    elseif self.Scope == MegaMacroScopes.Inactive then
        RemoveItemFromArray(MegaMacroGlobalData.InactiveMacros, self)
    end

    MegaMacroEngine.OnMacroDeleted(self)
    MegaMacroCodeInfo.Clear(self.Id)
    MegaMacroIconEvaluator.RemoveMacroFromCache(self.Id)
end

function MegaMacro.Move(self, newScope)
    local newMacro = MegaMacro.Create(self.DisplayName, newScope, self.StaticTexture)
    if not newMacro then
        return nil
    end
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
    elseif scope == MegaMacroScopes.Inactive then
        return MegaMacroGlobalData.InactiveMacros
    end
end
-- Forever keeps one spec list for each class. Older versions kept one for each spec or talent group
-- (Primary and Secondary), so those are merged into it, preferredKey first, then Primary, then the rest.
-- Their IDs are kept, which keeps them on action bars. A macro whose ID the merged list already has
-- goes to the Inactive tab under a new ID. Returns how many went there.
function MegaMacro.MergeSpecializations(classKey, preferredKey)
    local classData = MegaMacroGlobalData.Classes[classKey]

    if not classData or type(classData.Specializations) ~= "table" then
        return 0
    end

    local specializations = classData.Specializations
    local keys = {}

    for key in pairs(specializations) do
        if key ~= MegaMacroSharedSpecialization then
            table.insert(keys, key)
        end
    end

    if #keys == 0 then
        return 0
    end

    local function Rank(key)
        if key == preferredKey then
            return 1
        elseif key == DUAL_SPEC_PRIMARY then
            return 2
        end

        return 3
    end

    table.sort(keys, function(left, right)
        if Rank(left) ~= Rank(right) then
            return Rank(left) < Rank(right)
        end

        return tostring(left) < tostring(right)
    end)

    local shared = specializations[MegaMacroSharedSpecialization] or { Macros = {} }
    specializations[MegaMacroSharedSpecialization] = shared

    local usedIds = {}
    for _, macro in ipairs(shared.Macros) do
        usedIds[macro.Id] = true
    end

    local inactiveCount = 0

    for _, key in ipairs(keys) do
        local leftovers = {}

        for _, macro in ipairs(specializations[key].Macros or {}) do
            if not usedIds[macro.Id] then
                usedIds[macro.Id] = true
                macro.Specialization = MegaMacroSharedSpecialization
                table.insert(shared.Macros, macro)
            else
                local inactiveMacros = MegaMacroGlobalData.InactiveMacros
                local id = #inactiveMacros < MacroLimits.InactiveCount
                    and GetNextAvailableMacroId(MacroIndexOffsets.Inactive, MacroLimits.InactiveCount, inactiveMacros)

                if id then
                    macro.Id = id
                    macro.Scope = MegaMacroScopes.Inactive
                    macro.Specialization = nil
                    table.insert(inactiveMacros, macro)
                    inactiveCount = inactiveCount + 1
                else
                    -- With no room it stays where it was, so it's still in backups
                    table.insert(leftovers, macro)
                end
            end
        end

        if #leftovers == 0 then
            specializations[key] = nil
        else
            specializations[key].Macros = leftovers
        end
    end

    return inactiveCount
end
