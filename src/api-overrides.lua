MegaMacroApiOverrides = {
    Original = {
        GetMacroInfo = GetMacroInfo,
        GetMacroSpell = GetMacroSpell,
        GetMacroItem = GetMacroItem,
        GetActionCooldown = GetActionCooldown,
        GetActionCount = GetActionCount,
        GetActionTexture = GetActionTexture,
        GetActionCharges = GetActionCharges,
        IsUsableAction = IsUsableAction,
        IsActionInRange = IsActionInRange,
        PickupAction = PickupAction,
        IsEquippedAction = IsEquippedAction
    }
}

local function GetMegaMacroId(macroIndexOrName)
    if type(macroIndexOrName) == "string" then
        macroIndexOrName = GetMacroIndexByName(macroIndexOrName)
    end

    if macroIndexOrName <= MacroLimits.MaxGlobalMacros and not MegaMacroGlobalData.Activated or macroIndexOrName > MacroLimits.MaxGlobalMacros and not MegaMacroCharacterData.Activated then
        return nil
    end

    return MegaMacroEngine.GetMacroIdFromIndex(macroIndexOrName)
end

local function GetMegaMacroSpell(macroId)
    local abilityName = MegaMacroIconEvaluator.GetSpellFromCache(macroId)

    if abilityName then
        local spellId = select(7, GetSpellInfo(abilityName))
        if spellId then
            return spellId
        end

        local itemId = GetItemInfoInstant(abilityName)
        if itemId then
            _, spellId = GetItemSpell(itemId)
            if spellId then
                return spellId
            end
        end
    end

    return nil
end

local function GetMegaMacroItem(macroId)
    local abilityName = MegaMacroIconEvaluator.GetSpellFromCache(macroId)

    if abilityName then
        local spellId = select(7, GetSpellInfo(abilityName))
        if spellId then
            return nil
        end

        local itemId = GetItemInfoInstant(abilityName)
        if itemId then
            return itemId
        end
    end

    return nil
end

function GetMacroInfo(macroNameOrIndex)
    local macroId = GetMegaMacroId(macroNameOrIndex)

    if macroId then
        local macroName, _, body, isLocal = MegaMacroApiOverrides.Original.GetMacroInfo(macroNameOrIndex)
        local macroTexture = MegaMacroIconEvaluator.GetTextureFromCache(macroId)
        return macroName, macroTexture, body, isLocal
    end

    return MegaMacroApiOverrides.Original.GetMacroInfo(macroNameOrIndex)
end

function GetMacroSpell(macroNameOrIndex)
    local macroId = GetMegaMacroId(macroNameOrIndex)

    if macroId then
        local spellId = GetMegaMacroSpell(macroId)
        if spellId then
            return spellId
        end
    end

    return MegaMacroApiOverrides.Original.GetMacroSpell(macroNameOrIndex)
end

function GetMacroItem(macroNameOrIndex)
    local macroId = GetMegaMacroId(macroNameOrIndex)

    if macroId then
        local itemId = GetMegaMacroItem(macroId)
        if itemId then
            return itemId
        end
    end

    return MegaMacroApiOverrides.Original.GetMacroItem(macroNameOrIndex)
end

function GetActionCooldown(action)
    local type, id = GetActionInfo(action)

    if type == "macro" then
        local spellId = GetMacroSpell(id)
        if spellId then
            return GetSpellCooldown(spellId)
        end
        local itemId = GetMacroItem(id)
        if itemId then
            return GetItemCooldown(itemId)
        end
    end

    return MegaMacroApiOverrides.Original.GetActionCooldown(action)
end

function GetActionCount(action)
    local type, id = GetActionInfo(action)

    if type == "macro" then
        local spellId = GetMacroSpell(id)
        if spellId then
            return GetSpellCount(spellId)
        end
        local itemId = GetMacroItem(id)
        if itemId then
            return GetItemCount(itemId) or 0
        end
    end

    return MegaMacroApiOverrides.Original.GetActionCount(action)
end

function GetActionTexture(action)
    local type, id = GetActionInfo(action)

    if type == "macro" then
        local macroId = MegaMacroEngine.GetMacroIdFromIndex(id)
        if macroId then
            return MegaMacroIconEvaluator.GetTextureFromCache(macroId)
        end
    end

    return MegaMacroApiOverrides.Original.GetActionTexture(action)
end

function GetActionCharges(action)
    local type, id = GetActionInfo(action)

    if type == "macro" then
        local spellId = GetMacroSpell(id)
        if spellId then
            local charges, maxCharges, chargeStart, chargeDuration, chargeModRate = GetSpellCharges(spellId)
            maxCharges = maxCharges or 0
            return charges, maxCharges, chargeStart, chargeDuration, chargeModRate
        end
    end

    return MegaMacroApiOverrides.Original.GetActionCharges(action)
end

function IsUsableAction(action)
    local type, id = GetActionInfo(action)

    if type == "macro" then
        local spellId = GetMacroSpell(id)
        if spellId then
            return IsUsableSpell(spellId)
        end
        local itemId = GetMacroItem(id)
        if itemId then
            return IsUsableItem(itemId)
        end
    end

    return MegaMacroApiOverrides.Original.IsUsableAction(action)
end

function IsActionInRange(action)
    local type, id = GetActionInfo(action)

    if type == "macro" then
        local spellId = GetMacroSpell(id)
        if spellId then
            local spellIndex = FindSpellBookSlotBySpellID(spellId)
            if spellIndex then
                local macroId = MegaMacroEngine.GetMacroIdFromIndex(id)
                local target = macroId and MegaMacroIconEvaluator.GetTargetFromCache(macroId)
                return IsSpellInRange(spellIndex, BOOKTYPE_SPELL, target) ~= 0
            end
        end
        local itemId = GetMacroItem(id)
        if itemId then
            local macroId = MegaMacroEngine.GetMacroIdFromIndex(id)
            local target = macroId and MegaMacroIconEvaluator.GetTargetFromCache(macroId)
            return IsItemInRange(itemId, target)
        end
    end

    return MegaMacroApiOverrides.Original.IsActionInRange(action)
end

function PickupAction(action)
    local type, id = GetActionInfo(action)

    if type == "macro" and not InCombatLockdown() then
        local macroId = MegaMacroEngine.GetMacroIdFromIndex(id)
        if macroId then
            EditMacro(id, nil, MegaMacroIconEvaluator.GetTextureFromCache(macroId), nil, true, id > MacroLimits.MaxGlobalMacros)
            MegaMacroApiOverrides.Original.PickupAction(action)
            -- revert icon so that if a macro is dragged during combat, it will show the blank icon instead of an out-of-date macro icon
            EditMacro(id, nil, MegaMacroTexture, nil, true, id > MacroLimits.MaxGlobalMacros)
            return
        end
    end

    MegaMacroApiOverrides.Original.PickupAction(action)
end

function IsEquippedAction(action)
    local type, id = GetActionInfo(action)
    if type == "macro" then
        local macroId = MegaMacroEngine.GetMacroIdFromIndex(id)
        if macroId then
            local itemId = GetMegaMacroItem(macroId)
            if itemId then
                return IsEquippedItem(itemId)
            end
        end
    end

    return MegaMacroApiOverrides.Original.IsEquippedAction(action)
end

local OriginalGameToolTipSetAction = GameTooltip.SetAction
function GameTooltip:SetAction(action)
    local type, id = GetActionInfo(action)

    if type == "macro" then
        local macroId = MegaMacroEngine.GetMacroIdFromIndex(id)
        if macroId then
            ShowToolTipForMegaMacro(macroId)
            return
        end
    end

    OriginalGameToolTipSetAction(self, action)
end