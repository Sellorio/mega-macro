local DefaultMacroTexture = 134400

local MaxGlobalMacros = 120
local MaxCharacterMacros = 18

local MacrosToUpdatePerMs = 2
local LastMacroScope = MegaMacro.Scopes.Global
local LastMacroList = nil
local LastMacroIndex = 0

local IconUpdatedCallbacks = {}
local MacroIconCache = {} -- icon ids
local MacroSpellCache = {} -- spell ids

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
    local icon = DefaultMacroTexture
    local spellName = nil

    local codeInfo = MegaMacroCodeInfo.Get(macro)
    local codeInfoLength = #codeInfo

    for i=1, codeInfoLength do
        local command = codeInfo[i]

        if command.Type == "showtooltip" or command.Type == "use" or command.Type == "cast" then
            local ability = SecureCmdOptionParse(command.Body)

            if ability ~= nil then
                local _, _, texture = GetSpellInfo(ability)

                if texture == nil then
                    _, _, _, _, _, _, _, _, _, texture = GetItemInfo(ability)
                end
                
                if texture ~= nil then
                    icon = texture
                    spellName = ability
                end
            end
        end
    end

    if MacroIconCache[macro.Id] ~= icon or MacroSpellCache[macro.Id] ~= spellName then
        MacroIconCache[macro.Id] = icon
        MacroSpellCache[macro.Id] = spellName

        for i=1, #IconUpdatedCallbacks do
            IconUpdatedCallbacks[i](macro.Id, MacroIconCache[macro.Id])
        end
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
    print("Inserting callback")
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