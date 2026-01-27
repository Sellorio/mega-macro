local MacrosToUpdatePerMs = 2
local LastMacroScope = MegaMacroScopes.Global
local LastMacroList = nil
local LastMacroIndex = 0

local IconUpdatedCallbacks = {}
local MacroEffectData = {} -- { Type = "spell" or "item" or "equipment set" or other, Name = "", Icon = 0, Target = "" }

-- Helper for 12.0 string trimming
local function TrimString(str)
    return str and str:match("^%s*(.-)%s*$") or ""
end

-- 12.0 Fix: QueryCastSequence is removed. We must manually parse the string.
-- We can only reliably get the FIRST spell in the sequence, as internal state is hidden.
local function GetFirstCastSequenceSpell(sequenceText)
    if not sequenceText then return nil end
    -- Strip reset conditions (e.g. reset=10/target)
    -- This regex looks for "reset=" followed by non-space chars, then optional space
    local clean = sequenceText:gsub("^reset=[^%s]+%s*", "")
    -- Split by comma to get the list of spells
    local firstItem = strsplit(",", clean)
    return TrimString(firstItem)
end

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

    if not LastMacroList or LastMacroIndex > #LastMacroList then
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

        -- 12.0 Safety: If GetMacrosInScope returns nil (e.g. data not ready), retry cleanly
        if not LastMacroList then 
            LastMacroList = {} 
        end

        return IterateNextMacroInternal(nextScopeAttempts + 1)
    end

    return true
end

local function IterateNextMacro()
    return IterateNextMacroInternal(0)
end

local function GetAbilityData(ability)
    local slotId = tonumber(ability)

    if slotId then
        local itemId = GetInventoryItemID("player", slotId)
        if itemId then
            local itemName, _, _, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemId)
            return "item", itemId, itemName, itemTexture
        else
            return "unknown", nil, nil, MegaMacroTexture
        end
    else
        local spellInfo = C_Spell.GetSpellInfo(ability)
        local spellName, texture, spellId

        if spellInfo then
            spellName = spellInfo.name
            texture = spellInfo.iconID
            spellId = spellInfo.spellID
        end

        if spellId then
            local shapeshiftFormIndex = GetShapeshiftForm()
            local isActiveStance = false
            if shapeshiftFormIndex and shapeshiftFormIndex > 0 then
                local stanceSpellID
                -- 12.0 Compatibility for Shapeshift info
                if C_ShapeshiftForm then
                    local _, _, _, id = C_ShapeshiftForm.GetShapeshiftFormInfo(shapeshiftFormIndex)
                    stanceSpellID = id
                else
                    local _, _, _, id = GetShapeshiftFormInfo(shapeshiftFormIndex)
                    stanceSpellID = id
                end
                
                if stanceSpellID == spellId then
                    isActiveStance = true
                end
            end
            return "spell", spellId, spellName, isActiveStance and MegaMacroActiveStanceTexture or texture
        end

        local itemId, _, _, _, texture
        -- 12.0: C_Item.GetItemInfoInstant returns a tuple
        itemId, _, _, _, texture = C_Item.GetItemInfoInstant(ability)
        
        if texture then
            if C_ToyBox and C_ToyBox.GetToyInfo(itemId) then
                spellName, spellId = C_Item.GetItemSpell(itemId)
                if spellId then
                    return "spell", spellId, spellName, texture
                end
            end
            return "item", itemId, ability, texture
        end

        return "unknown", nil, ability, MegaMacroTexture
    end
end

local function GetIconForButton(buttonName)
    local icon = nil
    local button = _G[buttonName]
    if button then
        local iconFrame = button.icon or _G[buttonName.."Icon"]
        if iconFrame and iconFrame.GetTexture then
            icon = iconFrame:GetTexture()
        end
    end
    return icon
end

local function ComputeMacroIcon(macro, staticTexture, isStaticTextureFallback)
    local icon = not isStaticTextureFallback and staticTexture or MegaMacroTexture
    local effectType = nil
    local effectId = nil
    local effectName = nil
    local target = nil

    if icon == MegaMacroTexture then
        local codeInfo = MegaMacroCodeInfo.Get(macro)
        -- 12.0 Safety: Handle missing code info
        if not codeInfo then return nil, nil, nil, MegaMacroTexture, nil end

        local codeInfoLength = #codeInfo

        for i = 1, codeInfoLength do
            local command = codeInfo[i]

            if command.Type == "showtooltip" or command.Type == "use" or command.Type == "cast" then
                local ability, tar = SecureCmdOptionParse(command.Body)

                if ability ~= nil then
                    effectType, effectId, effectName, icon = GetAbilityData(ability)

                    -- skip spells or items that do not exist
                    if effectType ~= "unknown" then
                        target = tar
                        break
                    end
                end
            elseif command.Type == "castsequence" then
                local sequenceCode, tar = SecureCmdOptionParse(command.Body)

                if sequenceCode ~= nil then
                    -- 12.0 FIX: QueryCastSequence was REMOVED.
                    -- We fallback to parsing the first spell in the sequence.
                    local ability = GetFirstCastSequenceSpell(sequenceCode)

                    if ability ~= nil then
                        effectType, effectId, effectName, icon = GetAbilityData(ability)
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
                    effectType = "other"
                    icon = GetTextureFromPetCommand(command.Command)
                    if command.Command == "dismiss" then
                        effectName = "Dismiss Pet"
                    end
                    break
                end
            elseif command.Type == "equipset" then
                local setName = SecureCmdOptionParse(command.Body)
                if setName then
                    local setId = C_EquipmentSet.GetEquipmentSetID(setName)
                    effectType = "equipment set"
                    effectName = setName
                    if setId then
                        local _, setIcon = C_EquipmentSet.GetEquipmentSetInfo(setId)
                        icon = setIcon
                    end
                end
            elseif command.Type == "click" then
                local buttonName = SecureCmdOptionParse(command.Body)
                if buttonName then
                    effectType = "other"
                    effectName = buttonName
                    icon = GetIconForButton(buttonName)
                end
            end
        end

        if (icon == nil or icon == MegaMacroTexture) and isStaticTextureFallback and staticTexture ~= MegaMacroTexture then
            effectType = "fallback"
            icon = staticTexture
        elseif effectType == nil and codeInfoLength > 0 then
            local lastCmd = codeInfo[codeInfoLength]
            if lastCmd.Type == "fallbackAbility" then
                local ability = lastCmd.Body
                effectType, effectId, effectName, icon = GetAbilityData(ability)
            elseif lastCmd.Type == "fallbackSequence" then
                -- 12.0 Fix: Manual parse
                local ability = GetFirstCastSequenceSpell(lastCmd.Body)
                effectType, effectId, effectName, icon = GetAbilityData(ability)
            elseif lastCmd.Type == "fallbackPetCommand" then
                icon = GetTextureFromPetCommand(lastCmd.Body)
            elseif lastCmd.Type == "fallbackEquipmentSet" then
                effectType = "equipment set"
                effectName = lastCmd.Body
                local setId = C_EquipmentSet.GetEquipmentSetID(effectName)
                if setId then
                    local _, setIcon = C_EquipmentSet.GetEquipmentSetInfo(setId)
                    icon = setIcon
                end
            elseif lastCmd.Type == "fallbackClick" then
                effectType = "other"
                effectName = lastCmd.Body
                icon = GetIconForButton(effectName)
            end
        end
    end

    return effectType, effectId, effectName, icon, target
end

local function UpdateMacro(macro)
    local effectType, effectId, effectName, icon, target = ComputeMacroIcon(macro, macro.StaticTexture, macro.IsStaticTextureFallback)
    
    local currentData = MacroEffectData[macro.Id]
    if not currentData then
        currentData = {}
        MacroEffectData[macro.Id] = currentData
    end

    if currentData.Type ~= effectType
        or currentData.Id ~= effectId
        or currentData.Name ~= effectName
        or currentData.Icon ~= icon
        or currentData.Target ~= target then

        currentData.Type    = effectType
        currentData.Id      = effectId
        currentData.Name    = effectName
        currentData.Icon    = icon
        currentData.Target  = target

        for i = 1, #IconUpdatedCallbacks do
            IconUpdatedCallbacks[i](macro.Id, icon)
        end
    end

    if MegaMacroConfig and MegaMacroConfig['UseNativeActionBar'] then
        return
    end

    -- 12.0: Removed SetMacroSpell/SetMacroItem usage.
    -- We now must check C_Macro info and EditMacro if needed.
    local macroIndex = MegaMacroEngine.GetMacroIndexFromId(macro.Id)
    if macroIndex and not InCombatLockdown() then
        local name, currentIcon, body = C_Macro.GetMacroInfo(macroIndex)
        
        -- If the icon calculated (effectIcon) is different from the macro's current icon, update it.
        -- Note: effectName implies #showtooltip logic, but for native action bars 
        -- we primarily care about the texture being correct on the button.
        if icon and currentIcon ~= icon then
            C_Macro.EditMacro(macroIndex, nil, icon, nil)
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
    MacroEffectData = {}

    LastMacroScope = MegaMacroScopes.Global
    LastMacroList = MegaMacroGlobalData.Macros
    LastMacroIndex = 0

    local totalMacros = MacroLimits.MaxGlobalMacros + MacroLimits.MaxCharacterMacros
    for _ = 1, totalMacros do
        local previousLastMacroScope  = LastMacroScope
        local previousLastMacroList   = LastMacroList
        local previousLastMacroIndex  = LastMacroIndex

        if not IterateNextMacro() then
            break
        end

        -- Check if we've looped or data is invalid
        if not LastMacroList or not LastMacroList[LastMacroIndex] then
            break
        end

        -- Cycle detection
        if MacroEffectData[LastMacroList[LastMacroIndex].Id] then
            LastMacroScope = previousLastMacroScope
            LastMacroList  = previousLastMacroList
            LastMacroIndex = previousLastMacroIndex
            break
        end

        local macro = LastMacroList[LastMacroIndex]
        UpdateMacro(macro)

        -- Advance
        if not IterateNextMacroInternal(0) then
            break
        end
    end
end

MegaMacroIconEvaluator = {}
MegaMacroIconEvaluator.ComputeMacroIcon = ComputeMacroIcon

function MegaMacroIconEvaluator.Initialize()
    UpdateAllMacros()
end

function MegaMacroIconEvaluator.Update(elapsedMs)
    local macrosToScan = elapsedMs * MacrosToUpdatePerMs

    for _ = 1, macrosToScan do
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
    MacroEffectData[newId] = MacroEffectData[oldId]
end

function MegaMacroIconEvaluator.UpdateMacro(macro)
    UpdateMacro(macro)
end

function MegaMacroIconEvaluator.GetCachedData(macroId)
    return MacroEffectData[macroId]
end

function MegaMacroIconEvaluator.RemoveMacroFromCache(macroId)
    MacroEffectData[macroId] = nil
end

function MegaMacroIconEvaluator.ResetCache()
    UpdateAllMacros()
end