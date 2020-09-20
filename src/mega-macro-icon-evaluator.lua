local DefaultMacroTexture = 134400

local MaxGlobalMacros = 120
local MaxCharacterMacros = 18

local MacrosToUpdatePerMs = 2
local LastMacroScope = MegaMacro.Scopes.Global
local LastMacroList = nil
local LastMacroIndex = 0

local IconUpdatedCallbacks = {}
local MacroIconCache = {}
local MacroSpellCache = {}

local function IterateNextMacroInternal(nextScopeAttempts)
    LastMacroIndex = LastMacroIndex + 1

    if LastMacroIndex > #LastMacroList then
        -- limit the recursive iteration to going through each scope once
        if nextScopeAttempts > 5 then
            return false
        end

        if LastMacroScope == MegaMacro.Scopes.Global then
            LastMacroScope = MegaMacro.Scopes.Class
        elseif LastMacroScope == MegaMacro.Scopes.Class then
            LastMacroScope = MegaMacro.Scopes.Specialization
        elseif LastMacroScope == MegaMacro.Scopes.Specialization then
            LastMacroScope = MegaMacro.Scopes.Character
        elseif LastMacroScope == MegaMacro.Scopes.Character then
            LastMacroScope = MegaMacro.Scopes.CharacterSpecialization
        elseif LastMacroScope == MegaMacro.Scopes.CharacterSpecialization then
            LastMacroScope = MegaMacro.Scopes.Global
        end

        LastMacroIndex = 0
        LastMacroList = MegaMacro.GetMacrosInScope(LastMacroScope)

        return IterateNextMacroInternal(nextScopeAttempts)
    end

    return true
end

local function IterateNextMacro()
    return IterateNextMacroInternal(0)
end

local function UpdateMacro(macro)
    MacroIconCache[macro.Id] = DefaultMacroTexture
    MacroSpellCache[macro.Id] = nil

    for i=1, #IconUpdatedCallbacks do
        IconUpdatedCallbacks[i](macro.Id, MacroIconCache[macro.Id])
    end
end

local function UpdateNextMacro()
    if not IterateNextMacro() then
        return false
    end

    local macro = LastMacroList[LastMacroIndex]
    UpdateMacro(macro)

    return true
end

local function UpdateAllMacros()
    MacroIconCache = {}
    MacroSpellCache = {}

    LastMacroScope = MegaMacro.Scopes.Global
    LastMacroList = MegaMacroGlobalData.Macros
    LastMacroIndex = 0

    for _=1, (MaxGlobalMacros + MaxCharacterMacros) do
        local previousLastMacroScope = LastMacroScope
        local previousLastMacroList = LastMacroList
        local previousLastMacroIndex = LastMacroIndex

        if not IterateNextMacro() then
            break
        end

        if MacroIconCache[LastMacroList[LastMacroIndex].Id] then
            LastMacroScope = previousLastMacroScope
            LastMacroList = previousLastMacroList
            LastMacroIndex = previousLastMacroIndex
            break
        end
    
        local macro = LastMacroList[LastMacroIndex]
        UpdateMacro(macro)

        if not UpdateNextMacro() then
            break
        end
    end
end

MegaMacroIconEvaluator = {}

function MegaMacroIconEvaluator.Initialize()
    UpdateAllMacros()
end

function MegaMacroIconEvaluator.Update(elapsedMs)
    local macrosToScan = elapsedMs * MacrosToUpdatePerMs

    for _=1, macrosToScan do
        if not UpdateNextMacro() then
            break
        end
    end
end

-- callback takes 2 parameters: macroId and texture
function MegaMacroIconEvaluator.OnIconUpdated(fn)
    table.insert(IconUpdatedCallbacks, fn)
end

function MegaMacroIconEvaluator.ChangeMacroKey(oldId, newId)
    MacroIconCache[newId] = MacroIconCache[oldId]
    MacroSpellCache[newId] = MacroSpellCache[oldId]
end

function MegaMacroIconEvaluator.UpdateMacro(macro)
    UpdateMacro(macro)
end

function MegaMacroIconEvaluator.GetTextureFromCache(macroId)
    return MacroIconCache[macroId]
end

function MegaMacroIconEvaluator.GetSpellFromCache(macroId)
    return MacroSpellCache[macroId]
end

function MegaMacroIconEvaluator.RemoveMacroFromCache(macroId)
    MacroIconCache[macroId] = nil
    MacroSpellCache[macroId] = nil
end

function MegaMacroIconEvaluator.ResetCache()
    UpdateAllMacros()
end