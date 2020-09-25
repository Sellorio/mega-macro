local ActionBarProvider = nil

local function GetActionTextureWrapper(original, action)
    if MegaMacroGlobalData and MegaMacroCharacterData then
        local actionType, macroIndex = GetActionInfo(action)

        if actionType == "macro" then
            if macroIndex <= MacroLimits.MaxGlobalMacros and not MegaMacroGlobalData.Activated or macroIndex > MacroLimits.MaxGlobalMacros and not MegaMacroCharacterData.Activated then
                return original(action)
            end

            local macroId = MegaMacroEngine.GetMacroIdFromIndex(macroIndex)
            return MegaMacroIconEvaluator.GetTextureFromCache(macroId)
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
function MegaMacroActionBarEngine.SetIconBasedOnAction(icon, action)
    local actionType, macroIndex = GetActionInfo(action)

    if actionType == "macro" then
        if macroIndex <= MacroLimits.MaxGlobalMacros and not MegaMacroGlobalData.Activated or macroIndex > MacroLimits.MaxGlobalMacros and not MegaMacroCharacterData.Activated then
            return
        end

        local macroId = MegaMacroEngine.GetMacroIdFromIndex(macroIndex)
        local texture = MegaMacroIconEvaluator.GetTextureFromCache(macroId)
        icon:SetTexture(texture)
        return macroId
    end

    return nil
end