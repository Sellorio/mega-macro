local MacroBoundButtons = {}

local function OnIconUpdated(macroId, texture)
    local mouseFocus = GetMouseFocus()

    for _, info in pairs(MacroBoundButtons) do
        if info.MacroId == macroId then
            info.Button.icon:SetTexture(texture)

            if mouseFocus == info.Button then
                local macro = MegaMacro.GetById(macroId)

                if macro then
                    ShowToolTipForMegaMacro(macro)
                end
            end
        end
    end
end

local function ActionBarUpdateWrapper(original, self)
    original(self)

    if not MegaMacroGlobalData and not MegaMacroCharacterData then
        return
    end

    local selfRef = tostring(self)
    local macroId = MegaMacroActionBarEngine.SetIconBasedOnAction(self.icon, self.action)

    if macroId then
        MacroBoundButtons[selfRef] = { MacroId = macroId, Button = self }
    else
        MacroBoundButtons[selfRef] = nil
    end
end

local function ActionBarSetTooltipWrapper(original, self)
    original(self)

    if not MegaMacroGlobalData and not MegaMacroCharacterData then
        return
    end

    local selfRef = tostring(self)
    local action = self.action
    local actionType, macroIndex = GetActionInfo(action)

    if actionType == "macro" then
        if macroIndex <= MacroLimits.MaxGlobalMacros and not MegaMacroGlobalData.Activated or macroIndex > MacroLimits.MaxGlobalMacros and not MegaMacroCharacterData.Activated then
            return
        end

        local macroId = MegaMacroEngine.GetMacroIdFromIndex(macroIndex)
        local macro = MegaMacro.GetById(macroId)

        if macro then
            ShowToolTipForMegaMacro(macro)
        end
    else
        MacroBoundButtons[selfRef] = nil
    end
end

MegaMacroNativeUIActionBarProvider = {}

function MegaMacroNativeUIActionBarProvider.Initialize()
    local originalUpdate = ActionButton_Update
    ActionButton_Update = function(self) ActionBarUpdateWrapper(originalUpdate, self) end
    local originalSetTooltip = ActionButton_SetTooltip
    ActionButton_SetTooltip = function(self) ActionBarSetTooltipWrapper(originalSetTooltip, self) end

    MegaMacroIconEvaluator.OnIconUpdated(function(macroId, texture)
        OnIconUpdated(macroId, texture)
    end)
end

function MegaMacroNativeUIActionBarProvider.Update()
end