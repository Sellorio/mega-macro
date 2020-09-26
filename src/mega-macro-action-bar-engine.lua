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
        if not buffName then return false end

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
            return
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
        local abilityName = MegaMacroIconEvaluator.GetSpellFromCache(macroId)

        if abilityName and contains(MegaMacroStanceAbilities, string.lower(abilityName)) and PlayerHasBuff(abilityName) then
            icon:SetTexture(MegaMacroActiveStanceTexture)
            button:SetChecked(true)
        else
            button:SetChecked(false)
            local texture = MegaMacroIconEvaluator.GetTextureFromCache(macroId)
            icon:SetTexture(texture)
        end

        return macroId
    end

    return nil
end