local Native_ActionButton_Update = ActionButton_Update

local MacroBoundButtons = {}

local function OnIconUpdated(macroId, texture)
    for _, info in pairs(MacroBoundButtons) do
        if info.MacroId == macroId then
            info.Button.icon:SetTexture(texture)
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

        print("Updating texture for button bound to macroIndex "..macroIndex)
        local macroId = MegaMacroEngine.GetMacroIdFromIndex(macroIndex)
        local texture = MegaMacroIconEvaluator.GetTextureFromCache(macroId)
        MacroBoundButtons[selfRef] = { MacroId = macroId, Button = self }
        self.icon:SetTexture(texture)
    else
        MacroBoundButtons[selfRef] = nil
    end
end

MegaMacroActionBarHelper = {}

function MegaMacroActionBarHelper.Initialize()
    ActionButton_Update = function(self) ActionBarUpdateWrapper(self) end

    MegaMacroIconEvaluator.OnIconUpdated(function(macroId, texture)
        OnIconUpdated(macroId, texture)
    end)
end