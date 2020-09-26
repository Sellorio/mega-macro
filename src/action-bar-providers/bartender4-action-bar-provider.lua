local function ShowTooltipForButton(action)
    local actionType, macroIndex = GetActionInfo(action)

    if actionType == "macro" then
        if macroIndex <= MacroLimits.MaxGlobalMacros and not MegaMacroGlobalData.Activated or macroIndex > MacroLimits.MaxGlobalMacros and not MegaMacroCharacterData.Activated then
            return
        end

        local macroId = MegaMacroEngine.GetMacroIdFromIndex(macroIndex)

        if macroId then
            local macro = MegaMacro.GetById(macroId)
            ShowToolTipForMegaMacro(macro)
        end
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
            MegaMacroActionBarEngine.SetIconBasedOnAction(button, button.icon, action)

            if focus == button then
                ShowTooltipForButton(action)
            end
        end
    end
end

--[[

function UpdateCooldown(self)
	local locStart, locDuration = self:GetLossOfControlCooldown()
	local start, duration, enable, modRate = self:GetCooldown()
	local charges, maxCharges, chargeStart, chargeDuration, chargeModRate = self:GetCharges()

	self.cooldown:SetDrawBling(self.cooldown:GetEffectiveAlpha() > 0.5)

	if (locStart + locDuration) > (start + duration) then
		if self.cooldown.currentCooldownType ~= COOLDOWN_TYPE_LOSS_OF_CONTROL then
			self.cooldown:SetEdgeTexture("Interface\\Cooldown\\edge-LoC")
			self.cooldown:SetSwipeColor(0.17, 0, 0)
			self.cooldown:SetHideCountdownNumbers(true)
			self.cooldown.currentCooldownType = COOLDOWN_TYPE_LOSS_OF_CONTROL
		end
		CooldownFrame_Set(self.cooldown, locStart, locDuration, true, true, modRate)
	else
		if self.cooldown.currentCooldownType ~= COOLDOWN_TYPE_NORMAL then
			self.cooldown:SetEdgeTexture("Interface\\Cooldown\\edge")
			self.cooldown:SetSwipeColor(0, 0, 0)
			self.cooldown:SetHideCountdownNumbers(false)
			self.cooldown.currentCooldownType = COOLDOWN_TYPE_NORMAL
		end
		if locStart > 0 then
			self.cooldown:SetScript("OnCooldownDone", OnCooldownDone)
		end

		if charges and maxCharges and maxCharges > 1 and charges < maxCharges then
			StartChargeCooldown(self, chargeStart, chargeDuration, chargeModRate)
		elseif self.chargeCooldown then
			EndChargeCooldown(self.chargeCooldown)
		end
		CooldownFrame_Set(self.cooldown, start, duration, enable, false, modRate)
	end
end

]]