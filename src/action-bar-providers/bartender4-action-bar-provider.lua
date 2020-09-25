local function ShowTooltipForButton(action)
    local actionType, macroIndex = GetActionInfo(action)

    if actionType == "macro" then
        if macroIndex <= MacroLimits.MaxGlobalMacros and not MegaMacroGlobalData.Activated or macroIndex > MacroLimits.MaxGlobalMacros and not MegaMacroCharacterData.Activated then
            return
        end

        local macroId = MegaMacroEngine.GetMacroIdFromIndex(macroIndex)
        local macro = MegaMacro.GetById(macroId)

        ShowToolTipForMegaMacro(macro)
    end
end

MegaMacroBartender4ActionBarProvider = {}

function MegaMacroBartender4ActionBarProvider.Initialize()
end

function MegaMacroBartender4ActionBarProvider.Update()
    local focus = GetMouseFocus()

    for i=1, 120 do
        local buttonName = "BT4Button"..i
        local button = _G[buttonName]

        if button then
            local action = ActionButton_CalculateAction(button)
            MegaMacroActionBarEngine.SetIconBasedOnAction(button.icon, action)

            if focus == button then
                ShowTooltipForButton(action)
            end
        end
    end
end