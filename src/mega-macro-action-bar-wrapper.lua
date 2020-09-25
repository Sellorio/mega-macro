local Native_ActionButton_Update = ActionButton_Update
local Native_ActionButton_SetTooltip = ActionButton_SetTooltip

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

local function ActionBarUpdateWrapper(self)
    Native_ActionButton_Update(self)

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
        local texture = MegaMacroIconEvaluator.GetTextureFromCache(macroId)
        MacroBoundButtons[selfRef] = { MacroId = macroId, Button = self }
        self.icon:SetTexture(texture)
    else
        MacroBoundButtons[selfRef] = nil
    end
end

local function ActionBarSetTooltipWrapper(self)
    Native_ActionButton_SetTooltip(self)

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

MegaMacroActionBarWrapper = {}

function MegaMacroActionBarWrapper.Initialize()
    ActionButton_Update = function(self) ActionBarUpdateWrapper(self) end
    ActionButton_SetTooltip = function(self) ActionBarSetTooltipWrapper(self) end

    MegaMacroIconEvaluator.OnIconUpdated(function(macroId, texture)
        OnIconUpdated(macroId, texture)
    end)
end