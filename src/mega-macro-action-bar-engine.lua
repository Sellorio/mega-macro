local ActionBarProvider = nil

local function contains(tab, val)
    for _, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

local function PlayerHasBuff(buffName)
    local i = 1
    while true do
        local name = UnitBuff("player", i)

        if name == buffName then return true end
        if not name then return false end

        i = i + 1
    end
end

local function GetActionCooldownWrapper(original, action)
    local actionType, macroIndex = GetActionInfo(action)

    if actionType == "macro" then
        if macroIndex <= MacroLimits.MaxGlobalMacros and not MegaMacroGlobalData.Activated or macroIndex > MacroLimits.MaxGlobalMacros and not MegaMacroCharacterData.Activated then
            return original(action)
        end

        local macroId = MegaMacroEngine.GetMacroIdFromIndex(macroIndex)

        if macroId then
            local abilityName = MegaMacroIconEvaluator.GetSpellFromCache(macroId)

            if abilityName then
                local spellId = select(7, GetSpellInfo(abilityName))
                if spellId then
                    return GetSpellCooldown(spellId)
                end

                local itemId = GetItemInfoInstant(abilityName)
                if itemId then
                    return GetItemCooldown(itemId)
                end
            end
        end
    end

    return original(action)
end

local function GetActionChargesWrapper(original, action)
    local actionType, macroIndex = GetActionInfo(action)

    if actionType == "macro" then
        if macroIndex <= MacroLimits.MaxGlobalMacros and not MegaMacroGlobalData.Activated or macroIndex > MacroLimits.MaxGlobalMacros and not MegaMacroCharacterData.Activated then
            return original(action)
        end

        local macroId = MegaMacroEngine.GetMacroIdFromIndex(macroIndex)

        if macroId then
            local abilityName = MegaMacroIconEvaluator.GetSpellFromCache(macroId)

            if abilityName then
                local spellId = select(7, GetSpellInfo(abilityName))
                if spellId then
                    local charges, maxCharges, chargeStart, chargeDuration, chargeModRate = GetSpellCharges(spellId)

                    if maxCharges == nil then
                        maxCharges = 0
                    end

                    return charges, maxCharges, chargeStart, chargeDuration, chargeModRate
                end
            end
        end
    end

    return original(action)
end

local function GetActionCountWrapper(original, action)
    local actionType, macroIndex = GetActionInfo(action)

    if actionType == "macro" then
        if macroIndex <= MacroLimits.MaxGlobalMacros and not MegaMacroGlobalData.Activated or macroIndex > MacroLimits.MaxGlobalMacros and not MegaMacroCharacterData.Activated then
            return 0
        end

        local macroId = MegaMacroEngine.GetMacroIdFromIndex(macroIndex)

        if macroId then
            local abilityName = MegaMacroIconEvaluator.GetSpellFromCache(macroId)

            if abilityName then
                local itemId = GetItemInfoInstant(abilityName)
                if itemId then
                    return GetItemCount(itemId) or 0
                end
            end
        end
    end

    return original(action)
end

local function PickupActionWrapper(original, action)
    local actionType, macroIndex = GetActionInfo(action)

    if not InCombatLockdown() and actionType == "macro" then
        if macroIndex <= MacroLimits.MaxGlobalMacros and not MegaMacroGlobalData.Activated or macroIndex > MacroLimits.MaxGlobalMacros and not MegaMacroCharacterData.Activated then
            original(action)
            return
        end

        local macroId = MegaMacroEngine.GetMacroIdFromIndex(macroIndex)

        if macroId then
            EditMacro(macroIndex, nil, MegaMacroIconEvaluator.GetTextureFromCache(macroId), nil, true, macroIndex > MacroLimits.MaxGlobalMacros)
            original(action)
            -- revert icon so that if a macro is dragged during combat, it will show the blank icon instead of an out-of-date macro icon
            EditMacro(macroIndex, nil, MegaMacroTexture, nil, true, macroIndex > MacroLimits.MaxGlobalMacros)
            return
        end
    end

    original(action)
end

local function IsUsableActionWrapper(original, action)
    local actionType, macroIndex = GetActionInfo(action)

    if actionType == "macro" then
        if macroIndex <= MacroLimits.MaxGlobalMacros and not MegaMacroGlobalData.Activated or macroIndex > MacroLimits.MaxGlobalMacros and not MegaMacroCharacterData.Activated then
            return original(action)
        end

        local macroId = MegaMacroEngine.GetMacroIdFromIndex(macroIndex)

        if macroId then
            local abilityName = MegaMacroIconEvaluator.GetSpellFromCache(macroId)

            if abilityName then
                local spellId = select(7, GetSpellInfo(abilityName))
                if spellId then
                    return IsUsableSpell(spellId)
                end

                local itemId = GetItemInfoInstant(abilityName)
                if itemId then
                    _, spellId = GetItemSpell(itemId)
                    if spellId then
                        return IsUsableSpell(spellId)
                    end

                    return IsUsableItem(itemId)
                end
            end
        end
    end

    return original(action)
end

local function IsActionInRangeWrapper(original, action)
    local actionType, macroIndex = GetActionInfo(action)

    if actionType == "macro" then
        if macroIndex <= MacroLimits.MaxGlobalMacros and not MegaMacroGlobalData.Activated or macroIndex > MacroLimits.MaxGlobalMacros and not MegaMacroCharacterData.Activated then
            return original(action)
        end

        local macroId = MegaMacroEngine.GetMacroIdFromIndex(macroIndex)

        if macroId then
            local abilityName = MegaMacroIconEvaluator.GetSpellFromCache(macroId)

            if abilityName then
                local spellId = select(7, GetSpellInfo(abilityName))
                if spellId then
                    local spellIndex = FindSpellBookSlotBySpellID(spellId)
                    if spellIndex then
                        local target = MegaMacroIconEvaluator.GetTargetFromCache(macroId)
                        return IsSpellInRange(spellIndex, BOOKTYPE_SPELL, target)
                    end
                end

                local itemId = GetItemInfoInstant(abilityName)
                if itemId then
                    local target = MegaMacroIconEvaluator.GetTargetFromCache(macroId)
                    return IsItemInRange(itemId, target)
                end
            end
        end
    end

    return original(action)
end

MegaMacroActionBarEngine = {}

function MegaMacroActionBarEngine.Initialize()
    if _G["BT4Button1"] then
        ActionBarProvider = MegaMacroBartender4ActionBarProvider
    else
        ActionBarProvider = MegaMacroNativeUIActionBarProvider
    end

    local originalGetActionCooldown = GetActionCooldown
    GetActionCooldown = function(action) return GetActionCooldownWrapper(originalGetActionCooldown, action) end
    local originalGetActionCharges = GetActionCharges
    GetActionCharges = function(action) return GetActionChargesWrapper(originalGetActionCharges, action) end
    local originalGetActionCount = GetActionCount
    GetActionCount = function(action) return GetActionCountWrapper(originalGetActionCount, action) end
    local originalPickupAction = PickupAction
    PickupAction = function(action) PickupActionWrapper(originalPickupAction, action) end
    local originalIsUsableAction = IsUsableAction
    IsUsableAction = function(action) return IsUsableActionWrapper(originalIsUsableAction, action) end
    local originalIsActionInRange = IsActionInRange
    IsActionInRange = function(action) return IsActionInRangeWrapper(originalIsActionInRange, action) end

    if ActionBarProvider then
        ActionBarProvider.Initialize()
    end
end

function MegaMacroActionBarEngine.OnUpdate()
    if ActionBarProvider then
        ActionBarProvider.Update()
    end
end

-- Returns: The macroId to which the action related
function MegaMacroActionBarEngine.SetIconBasedOnAction(button, icon, action)
    local actionType, macroIndex = GetActionInfo(action)

    if actionType == "macro" then
        if macroIndex <= MacroLimits.MaxGlobalMacros and not MegaMacroGlobalData.Activated or macroIndex > MacroLimits.MaxGlobalMacros and not MegaMacroCharacterData.Activated then
            return
        end

        local macroId = MegaMacroEngine.GetMacroIdFromIndex(macroIndex)

        if macroId then
            local abilityName = MegaMacroIconEvaluator.GetSpellFromCache(macroId)
            local isActive = false
            local isActiveStance = false

            if abilityName then
                if contains(MegaMacroStanceAbilities, string.lower(abilityName)) and PlayerHasBuff(abilityName) then
                    isActive = true
                    isActiveStance = true
                else
                    local spellId = select(7, GetSpellInfo(abilityName))
                    if spellId and IsCurrentSpell(spellId) then
                        isActive = true
                    end
                end
            end

            button:SetChecked(isActive)
            icon:SetTexture(isActiveStance and MegaMacroActiveStanceTexture or MegaMacroIconEvaluator.GetTextureFromCache(macroId))
            return macroId
        end
    end

    return nil
end