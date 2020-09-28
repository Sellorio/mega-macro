local MacrosToUpdatePerMs = 2
local LastMacroScope = MegaMacroScopes.Global
local LastMacroList = nil
local LastMacroIndex = 0

local IconUpdatedCallbacks = {}
local MacroIconCache = {} -- icon ids
local MacroSpellCache = {} -- spell ids
local MacroTargetCache = {} -- unit strings

local function GetTextureFromPetCommand(command)
    if command == "dismiss" then
        return PetActionTextures.Dismiss
    elseif command == "attack" then
        return PetActionTextures.Attack
    elseif command == "assist" then
        return PetActionTextures.Assist
    elseif command == "passive" then
        return PetActionTextures.Passive
    elseif command == "defensive" then
        return PetActionTextures.Defensive
    elseif command == "follow" then
        return PetActionTextures.Follow
    elseif command == "moveto" then
        return PetActionTextures.MoveTo
    elseif command == "stay" then
        return PetActionTextures.Stay
    end
end

local function IterateNextMacroInternal(nextScopeAttempts)
    LastMacroIndex = LastMacroIndex + 1

    if LastMacroIndex > #LastMacroList then
        -- limit the recursive iteration to going through each scope once
        if nextScopeAttempts > 5 then
            return false
        end

        if LastMacroScope == MegaMacroScopes.Global then
            LastMacroScope = MegaMacroScopes.Class
        elseif LastMacroScope == MegaMacroScopes.Class then
            LastMacroScope = MegaMacroScopes.Specialization
        elseif LastMacroScope == MegaMacroScopes.Specialization then
            LastMacroScope = MegaMacroScopes.Character
        elseif LastMacroScope == MegaMacroScopes.Character then
            LastMacroScope = MegaMacroScopes.CharacterSpecialization
        elseif LastMacroScope == MegaMacroScopes.CharacterSpecialization then
            LastMacroScope = MegaMacroScopes.Global
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

local function GetIconFromAbility(ability)
    return
        select(3, GetSpellInfo(ability)) or
        select(5, GetItemInfoInstant(ability))
end

local function UpdateMacro(macro)
    local icon = MegaMacroTexture
    local spellName = nil
    local target = nil

    local codeInfo = MegaMacroCodeInfo.Get(macro)
    local codeInfoLength = #codeInfo

    for i=1, codeInfoLength do
        local command = codeInfo[i]

        if command.Type == "showtooltip" or command.Type == "use" or command.Type == "cast" then
            local ability, tar = SecureCmdOptionParse(command.Body)

            if ability ~= nil then
                local texture = GetIconFromAbility(ability) or MegaMacroTexture
                icon = texture
                spellName = ability
                target = tar
                break
            end
        elseif command.Type == "castsequence" then
            local sequenceCode, tar = SecureCmdOptionParse(command.Body)

            if sequenceCode ~= nil then
                local _, item, spell = QueryCastSequence(sequenceCode)
                local ability = item or spell

                if ability ~= nil then
                    local texture = GetIconFromAbility(ability) or MegaMacroTexture
                    icon = texture
                    spellName = ability
                    target = tar
                    break
                end

                break
            end
        elseif command.Type == "stopmacro" then
            local shouldStop = SecureCmdOptionParse(command.Body)
            if shouldStop == "TRUE" then
                break
            end
        elseif command.Type == "petcommand" then
            local shouldRun = SecureCmdOptionParse(command.Body)
            if shouldRun == "TRUE" then
                icon = GetTextureFromPetCommand(command.Command)
                if command.Command == "dismiss" then
                    spellName = "Dismiss Pet"
                end
                break
            end
        end
    end

    if spellName == nil and icon == MegaMacroTexture and codeInfoLength > 0 then
        if codeInfo[codeInfoLength].Type == "fallbackAbility" then
            local ability = codeInfo[codeInfoLength].Body
            local texture = GetIconFromAbility(ability)

            if texture ~= nil then
                icon = texture
                spellName = ability
            end
        elseif codeInfo[codeInfoLength].Type == "fallbackSequence" then
            local ability = QueryCastSequence(codeInfo[codeInfoLength].Body)
            local texture = GetIconFromAbility(ability)

            if texture ~= nil then
                icon = texture
                spellName = ability
            end
        elseif codeInfo[codeInfoLength].Type == "fallbackPetCommand" then
            icon = GetTextureFromPetCommand(codeInfo[codeInfoLength].Body)
        end
    end

    if MacroIconCache[macro.Id] ~= icon or MacroSpellCache[macro.Id] ~= spellName then
        MacroIconCache[macro.Id] = icon
        MacroSpellCache[macro.Id] = spellName
        MacroTargetCache[macro.Id] = target

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
    MacroTargetCache = {}

    LastMacroScope = MegaMacroScopes.Global
    LastMacroList = MegaMacroGlobalData.Macros
    LastMacroIndex = 0

    for _=1, (MacroLimits.MaxGlobalMacros + MacroLimits.MaxCharacterMacros) do
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

function MegaMacroIconEvaluator.GetTargetFromCache(macroId)
    return MacroTargetCache[macroId]
end

function MegaMacroIconEvaluator.RemoveMacroFromCache(macroId)
    MacroIconCache[macroId] = nil
    MacroSpellCache[macroId] = nil
    MacroTargetCache[macroId] = nil
end

function MegaMacroIconEvaluator.ResetCache()
    UpdateAllMacros()
end