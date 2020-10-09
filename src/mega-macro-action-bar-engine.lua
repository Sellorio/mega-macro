--[[

For developer refererence, these are the features of an action bar button:
 - Texture
 - Cooldown (including silence/stun cooldown display)
 - Recharge cooldown
 - Is Usable
 - Insufficient Mana (or resource)
 - Is In Range
 - Is Current
 - Current Shapeshift Form (should appear as Is Current)
 - Count (spells or items). Example of spell count: Lesser Soul Fragments as displayed on Soul Cleave or Spirit Bomb.
 - Charges (spells only atm)
 - Spell Glow (such as on empowerments for Balance Druid)
 - Active Auto Attack Flash (flashes red when auto attack is active) - intentionally omitted from this addon

]]



local LibActionButton = nil
local BlizzardActionBars = { "Action", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft" }

local rangeTimer = 5
local updateRange = false

local function GetMacroAbilityInfo(macroId)
    local abilityName = MegaMacroIconEvaluator.GetSpellFromCache(macroId)

    if abilityName then
        local spellId = select(7, GetSpellInfo(abilityName))
        if spellId then
            return "spell", spellId
        end

        local itemId = GetItemInfoInstant(abilityName)
        if itemId and (IsEquippedItem(itemId) or C_ToyBox.GetToyInfo(itemId)) then
            _, spellId = GetItemSpell(itemId)
            if spellId then
                return "spell", spellId
            end
        end

        if itemId then
            return "item", itemId
        end
    end

    return "unknown", nil
end

local function UpdateCurrentActionState(button, functions, abilityId)
    local isChecked = functions.IsCurrent(abilityId) or functions.IsAutoRepeat(abilityId)

    if not isChecked and functions == MegaMacroInfoFunctions.Spell then
        local shapeshiftFormIndex = GetShapeshiftForm()
        if shapeshiftFormIndex and shapeshiftFormIndex > 0 and abilityId == select(4, GetShapeshiftFormInfo(shapeshiftFormIndex)) then
            isChecked = true
        end
    end

    if isChecked then
        button:SetChecked(true)
    else
        button:SetChecked(false)
    end
end

local function UpdateUsable(button, functions, abilityId)
    local icon = button.icon
	local normalTexture = button.NormalTexture
	if not normalTexture then
		return;
	end

	local isUsable, notEnoughMana = functions.IsUsable(abilityId)
	if isUsable then
		icon:SetVertexColor(1.0, 1.0, 1.0)
		normalTexture:SetVertexColor(1.0, 1.0, 1.0)
	elseif ( notEnoughMana ) then
		icon:SetVertexColor(0.5, 0.5, 1.0)
		normalTexture:SetVertexColor(0.5, 0.5, 1.0)
	else
		icon:SetVertexColor(0.4, 0.4, 0.4)
		normalTexture:SetVertexColor(1.0, 1.0, 1.0)
	end

	local isLevelLinkLocked = functions.IsLocked(abilityId)
	if not icon:IsDesaturated() then
		icon:SetDesaturated(isLevelLinkLocked)
	end

	if button.LevelLinkLockIcon then
		button.LevelLinkLockIcon:SetShown(isLevelLinkLocked)
	end
end

local function LibActionButton_EndChargeCooldown(self)
	self:Hide()
	self:SetParent(UIParent)
	self.parent.chargeCooldown = nil
	self.parent = nil
	tinsert(LibActionButton.ChargeCooldowns, self)
end

local function LibActionButton_StartChargeCooldown(parent, chargeStart, chargeDuration, chargeModRate)
	if not parent.chargeCooldown then
		local cooldown = tremove(LibActionButton.ChargeCooldowns)
		if not cooldown then
			LibActionButton.NumChargeCooldowns = LibActionButton.NumChargeCooldowns + 1
			cooldown = CreateFrame("Cooldown", "LAB10ChargeCooldown"..LibActionButton.NumChargeCooldowns, parent, "CooldownFrameTemplate");
			cooldown:SetScript("OnCooldownDone", LibActionButton_EndChargeCooldown)
			cooldown:SetHideCountdownNumbers(true)
			cooldown:SetDrawSwipe(false)
		end
		cooldown:SetParent(parent)
		cooldown:SetAllPoints(parent)
		cooldown:SetFrameStrata("TOOLTIP")
		cooldown:Show()
		parent.chargeCooldown = cooldown
		cooldown.parent = parent
	end
	-- set cooldown
	parent.chargeCooldown:SetDrawBling(parent.chargeCooldown:GetEffectiveAlpha() > 0.5)
	CooldownFrame_Set(parent.chargeCooldown, chargeStart, chargeDuration, true, true, chargeModRate)

	-- update charge cooldown skin when masque is used
	if Masque and Masque.UpdateCharge then
		Masque:UpdateCharge(parent)
	end

	if not chargeStart or chargeStart == 0 then
		LibActionButton_EndChargeCooldown(parent.chargeCooldown)
	end
end

local function UpdateCooldownLibActionButton(button, functions, abilityId)
    local locStart, locDuration = functions.GetLossOfControlCooldown(abilityId)
	local start, duration, enable, modRate = functions.GetCooldown(abilityId)
	local charges, maxCharges, chargeStart, chargeDuration, chargeModRate = functions.GetCharges(abilityId)

	button.cooldown:SetDrawBling(button.cooldown:GetEffectiveAlpha() > 0.5)

	if (locStart + locDuration) > (start + duration) then
		if button.cooldown.currentCooldownType ~= COOLDOWN_TYPE_LOSS_OF_CONTROL then
			button.cooldown:SetEdgeTexture("Interface\\Cooldown\\edge-LoC")
			button.cooldown:SetSwipeColor(0.17, 0, 0)
			button.cooldown:SetHideCountdownNumbers(true)
			button.cooldown.currentCooldownType = COOLDOWN_TYPE_LOSS_OF_CONTROL
		end
		CooldownFrame_Set(button.cooldown, locStart, locDuration, true, true, modRate)
	else
		if button.cooldown.currentCooldownType ~= COOLDOWN_TYPE_NORMAL then
			button.cooldown:SetEdgeTexture("Interface\\Cooldown\\edge")
			button.cooldown:SetSwipeColor(0, 0, 0)
			button.cooldown:SetHideCountdownNumbers(false)
			button.cooldown.currentCooldownType = COOLDOWN_TYPE_NORMAL
		end
		if locStart > 0 then
            button.cooldown:SetScript("OnCooldownDone", function()
                button:SetScript("OnCooldownDone", nil)
                UpdateCooldownLibActionButton(button, functions, abilityId)
            end)
		end

        if charges and maxCharges and charges > 0 and charges < maxCharges then
			LibActionButton_StartChargeCooldown(button, chargeStart, chargeDuration, chargeModRate)
		elseif button.chargeCooldown then
			LibActionButton_EndChargeCooldown(button.chargeCooldown)
		end
		CooldownFrame_Set(button.cooldown, start, duration, enable, false, modRate)
	end
end

local function UpdateCooldownBlizzard(button, functions, abilityId)
    locStart, locDuration = functions.GetLossOfControlCooldown(abilityId)
    start, duration, enable, modRate = functions.GetCooldown(abilityId)
    charges, maxCharges, chargeStart, chargeDuration, chargeModRate = functions.GetCharges(abilityId)

	if ( (locStart + locDuration) > (start + duration) ) then
		if ( button.cooldown.currentCooldownType ~= COOLDOWN_TYPE_LOSS_OF_CONTROL ) then
			button.cooldown:SetEdgeTexture("Interface\\Cooldown\\edge-LoC")
			button.cooldown:SetSwipeColor(0.17, 0, 0)
			button.cooldown:SetHideCountdownNumbers(true)
			button.cooldown.currentCooldownType = COOLDOWN_TYPE_LOSS_OF_CONTROL
		end

		CooldownFrame_Set(button.cooldown, locStart, locDuration, true, true, modRate)
		ClearChargeCooldown(button)
	else
		if ( button.cooldown.currentCooldownType ~= COOLDOWN_TYPE_NORMAL ) then
			button.cooldown:SetEdgeTexture("Interface\\Cooldown\\edge")
			button.cooldown:SetSwipeColor(0, 0, 0)
			button.cooldown:SetHideCountdownNumbers(false)
			button.cooldown.currentCooldownType = COOLDOWN_TYPE_NORMAL
		end

		if( locStart > 0 ) then
			button.cooldown:SetScript("OnCooldownDone", ActionButton_OnCooldownDone)
		end

		if ( charges and maxCharges and maxCharges > 1 and charges < maxCharges ) then
            StartChargeCooldown(button, chargeStart, chargeDuration, chargeModRate)
		else
			ClearChargeCooldown(button)
		end

		CooldownFrame_Set(button.cooldown, start, duration, enable, false, modRate)
	end
end

local function UpdateCount(button, functions, abilityId)
    local text = button.Count;
    if functions == MegaMacroInfoFunctions.Item and not IsEquippedItem(abilityId) then
        local count = GetItemCount(abilityId)
        text:SetText(count > (button.maxDisplayCount or 9999) and "*" or count)
    elseif functions == MegaMacroInfoFunctions.Spell then
        local charges, maxCharges, _, _ = functions.GetCharges(abilityId)
        if maxCharges and maxCharges > 0 then
            text:SetText(charges)
        else
            local count = functions.GetCount(abilityId)
            if count ~= nil and count > 0 then
                text:SetText(count)
            else
                text:SetText("")
            end
        end
    else
        text:SetText("")
    end
end

local function UpdateEquipped(button, functions, abilityId)
    if functions.IsEquipped(abilityId) then
		button.Border:SetVertexColor(0, 1.0, 0, 0.35)
		button.Border:Show()
	else
		button.Border:Hide()
	end
end

local function UpdateOverlayGlow(button, functions, abilityId)
    if functions.IsOverlayed(abilityId) then
        ActionButton_ShowOverlayGlow(button)
    else
        ActionButton_HideOverlayGlow(button)
    end
end

local function UpdateRangeTimer(elapsed)
    rangeTimer = rangeTimer - elapsed

    if rangeTimer < 0 then
        updateRange = true
        rangeTimer = 1
    else
        updateRange = false
    end
end

local function UpdateRange(button, functions, abilityId, target)
    local valid = functions.IsInRange(abilityId, target)
    local checksRange = (valid ~= nil);
    local inRange = checksRange and valid;
    rangeTimer = 1;

    if button.HotKey:GetText() == RANGE_INDICATOR then
		if checksRange then
			button.HotKey:Show();
			if ( inRange ) then
				button.HotKey:SetVertexColor(LIGHTGRAY_FONT_COLOR:GetRGB());
            else
				button.HotKey:SetVertexColor(RED_FONT_COLOR:GetRGB());
			end
		else
			button.HotKey:Hide();
		end
	else
		if checksRange and not inRange then
			button.HotKey:SetVertexColor(RED_FONT_COLOR:GetRGB());
		else
			button.HotKey:SetVertexColor(LIGHTGRAY_FONT_COLOR:GetRGB());
		end
	end
end

local function UpdateTexture(button, macroId)
    button.icon:SetTexture(MegaMacroIconEvaluator.GetTextureFromCache(macroId))
end

local function UpdateActionBar(button, macroId, elapsed)
    local abilityType, abilityId = GetMacroAbilityInfo(macroId)
    local functions = MegaMacroInfoFunctions.Unknown

    if abilityType == "spell" then
        functions = MegaMacroInfoFunctions.Spell
    elseif abilityType == "item" then
        functions = MegaMacroInfoFunctions.Item
    end

    UpdateCurrentActionState(button, functions, abilityId)
    UpdateUsable(button, functions, abilityId)
    UpdateCount(button, functions, abilityId)
    UpdateEquipped(button, functions, abilityId)
    UpdateOverlayGlow(button, functions, abilityId)
    UpdateTexture(button, macroId)

    if LibActionButton then
        UpdateCooldownLibActionButton(button, functions, abilityId)
    else
        UpdateCooldownBlizzard(button, functions, abilityId)
    end

    if updateRange then
        local target = MegaMacroIconEvaluator.GetTargetFromCache(macroId)
        UpdateRange(button, functions, abilityId, target)
    end
end

local function ForEachLibActionButton(func)
    for button, _ in pairs(LibActionButton.buttonRegistry) do
        func(button)
    end
end

local function ForEachBlizzardActionButton(func)
    for actionBarIndex=1, #BlizzardActionBars do
        for i=1, 12 do
            local button = _G[BlizzardActionBars[actionBarIndex].."Button"..i]
            if button then
                func(button)
            end
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

    MegaMacroIconEvaluator.OnIconUpdated(function()
        rangeTimer = -1
    end)
end

function MegaMacroActionBarEngine.OnUpdate(elapsed)
    UpdateRangeTimer(elapsed)

    local focus = GetMouseFocus()
    local iterator = LibActionButton and ForEachLibActionButton or ForEachBlizzardActionButton

    iterator(function(button)
        button.action = button.action == 0 and ActionButton_CalculateAction(button) or button.action
        local type, macroIndex = GetActionInfo(button.action)
        local macroId = type == "macro" and MegaMacroEngine.GetMacroIdFromIndex(macroIndex)

        if macroId then
            UpdateActionBar(button, macroId, elapsed)

            if button == focus then
                ShowToolTipForMegaMacro(macroId)
            end
        end
    end)
end

function MegaMacroActionBarEngine.OnTargetChanged()
    rangeTimer = -1
end