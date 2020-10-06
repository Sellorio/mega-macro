local LibActionButton = nil
local BoundMacroButtons = {}

-- local function ActionBarSetTooltipWrapper(original, self)
--     original(self)

--     if not MegaMacroGlobalData and not MegaMacroCharacterData then
--         return
--     end

--     local action = self.action
--     local actionType, macroIndex = GetActionInfo(action)

--     if actionType == "macro" then
--         if macroIndex <= MacroLimits.MaxGlobalMacros and not MegaMacroGlobalData.Activated or macroIndex > MacroLimits.MaxGlobalMacros and not MegaMacroCharacterData.Activated then
--             return
--         end

--         local macroId = MegaMacroEngine.GetMacroIdFromIndex(macroIndex)

--         if macroId then
--             ShowToolTipForMegaMacro(macroId)
--         end
--     end
-- end

local function UpdateActionBar(button)
    local icon = button.icon
    local action = button.action
    ActionButton_UpdateState(button)
    ActionButton_UpdateUsable(button)
    ActionButton_UpdateCooldown(button)
    ActionButton_UpdateFlash(button)
    ActionButton_UpdateHighlightMark(button)
    ActionButton_UpdateSpellHighlightMark(button)
    ActionButton_UpdateCount(button)
	ActionButton_UpdateFlyout(button);
    ActionButton_UpdateOverlayGlow(button);
    icon:SetTexture(GetActionTexture(action))

    -- forces immediate update of range idicator
    ActionButton_OnEvent(button, "PLAYER_TARGET_CHANGED")

    local border = button.Border;
	if border then
		if IsEquippedAction(action) then
			border:SetVertexColor(0, 1.0, 0, 0.35);
			border:Show();
		else
			border:Hide();
		end
	end
end

MegaMacroActionBarEngine = {}

function MegaMacroActionBarEngine.Initialize()
    if _G["BT4Button1"] then
        LibActionButton = LibStub("LibActionButton-1.0")
    elseif _G["ElvUI_Bar1Button1"] then
        LibActionButton = LibStub("LibActionButton-1.0-ElvUI")
    end
end

function MegaMacroActionBarEngine.OnUpdate()
    if LibActionButton then
        local libActionButtonOnEvent = LibActionButton.eventFrame:GetScript("OnEvent")
        libActionButtonOnEvent(LibActionButton.eventFrame, "PLAYER_ENTERING_WORLD", nil)
    else
        for _, button in pairs(BoundMacroButtons) do
            UpdateActionBar(button)
        end
    end

    local focus = GetMouseFocus()
    if focus and focus.action then
        local action = focus.action == 0 and ActionButton_CalculateAction(focus) or focus.action
        local type, id = GetActionInfo(action)
        if type == "macro" then
            local macroId = MegaMacroEngine.GetMacroIdFromIndex(id)
            if macroId then
                ShowToolTipForMegaMacro(macroId)
            end
        end
    end
end

hooksecurefunc("ActionButton_Update", function(self)
    if not MegaMacroGlobalData and not MegaMacroCharacterData then
        return
    end

    local actionType, macroIndex = GetActionInfo(self.action)

    if actionType == "macro" then
        if macroIndex <= MacroLimits.MaxGlobalMacros and not MegaMacroGlobalData.Activated or macroIndex > MacroLimits.MaxGlobalMacros and not MegaMacroCharacterData.Activated then
            return
        end

        local macroId = MegaMacroEngine.GetMacroIdFromIndex(macroIndex)
        if macroId then
            BoundMacroButtons[tostring(self)] = self
        else
            BoundMacroButtons[tostring(self)] = nil
        end
    else
        BoundMacroButtons[tostring(self)] = nil
    end
end)
