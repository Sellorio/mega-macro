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
local ActionBarSystem = nil -- Blizzard or LAB or Dominos
local BlizzardActionBars = { "Action", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft" }

local rangeTimer = 5
local updateRange = false

local ActionsBoundToMegaMacros = {}

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

	-- local isLevelLinkLocked = functions.IsLocked(abilityId)
	-- if not icon:IsDesaturated() then
	-- 	icon:SetDesaturated(isLevelLinkLocked)
	-- end

	-- if button.LevelLinkLockIcon then
	-- 	button.LevelLinkLockIcon:SetShown(isLevelLinkLocked)
	-- end
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
    local countLabel = button.Count
    local count = functions.GetCount(abilityId)

    local isNonEquippableItem = functions == MegaMacroInfoFunctions.Item and not IsEquippableItem(abilityId)
    local isNonItemWithCount = functions ~= MegaMacroInfoFunctions.Item and count and count > 0

    if isNonEquippableItem or isNonItemWithCount then
        countLabel:SetText(count > (button.maxDisplayCount or 9999) and "*" or count)
    else
        local charges, maxCharges = functions.GetCharges(abilityId)
		if charges and maxCharges and maxCharges > 1 then
			countLabel:SetText(charges)
		else
			countLabel:SetText("")
        end
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

	if Bartender4 then
		if Bartender4.db.profile.outofrange == "button" then
			if checksRange and not inRange then
				button.icon:SetVertexColor(
					Bartender4.db.profile.colors.range.r,
					Bartender4.db.profile.colors.range.g,
					Bartender4.db.profile.colors.range.b)
			else
				button.icon:SetVertexColor(1, 1, 1)
			end
		elseif Bartender4.db.profile.outofrange == "none" then
			return
		end
	end

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

local function UpdateActionBar(button, macroId)
    local data = MegaMacroIconEvaluator.GetCachedData(macroId)
    local functions = MegaMacroInfoFunctions.Unknown

	if data then
		if data.Type == "spell" then
			functions = MegaMacroInfoFunctions.Spell
		elseif data.Type == "item" then
			functions = MegaMacroInfoFunctions.Item
		elseif data.Type == "fallback" then
			functions = MegaMacroInfoFunctions.Fallback
		end

		UpdateCurrentActionState(button, functions, data.Id)
		UpdateUsable(button, functions, data.Id)
		UpdateCount(button, functions, data.Id)
		UpdateEquipped(button, functions, data.Id)
		UpdateOverlayGlow(button, functions, data.Id)
		button.icon:SetTexture(data.Icon or MegaMacroTexture)

		if LibActionButton then
			UpdateCooldownLibActionButton(button, functions, data.Id)
		else
			UpdateCooldownBlizzard(button, functions, data.Id)
		end

		if updateRange then
			UpdateRange(button, functions, data.Id, data.Target)
		end
	end
end

local function ResetActionBar(button)
	button:SetChecked(false)
	button.Count:SetText("")
	button.Border:Hide() -- reset eqipped border
	ActionButton_HideOverlayGlow(button)
	ClearChargeCooldown(button)
	UpdateRange(button, MegaMacroInfoFunctions.Unknown)
	button.icon:SetVertexColor(1.0, 1.0, 1.0) -- reset opacity (is usable visuals)

	local normalTexture = button.NormalTexture
	if normalTexture then
		normalTexture:SetVertexColor(1.0, 1.0, 1.0) -- reset blue shift
	end
end

local function ForEachLibActionButton(func)
    for button, _ in pairs(LibActionButton.buttonRegistry) do
        func(button)
    end
end

local function ForEachDominosButton(func)
	for i=1, 120 do
		local button = nil
		if i <= 12 then
			button = _G[('ActionButton%d'):format(i)]
		elseif i <= 24 then
			button = _G["DominosActionButton"..(i - 12)]
		elseif i <= 36 then
			button = _G[('MultiBarRightButton%d'):format(i - 24)]
		elseif i <= 48 then
			button = _G[('MultiBarLeftButton%d'):format(i - 36)]
		elseif i <= 60 then
			button = _G[('MultiBarBottomRightButton%d'):format(i - 48)]
		elseif i <= 72 then
			button = _G[('MultiBarBottomLeftButton%d'):format(i - 60)]
		else
			button = _G["DominosActionButton"..(i - 60)]
		end
		if button then
			func(button)
		end
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
		ActionBarSystem = "LAB"
    elseif _G["ElvUI_Bar1Button1"] then
		LibActionButton = LibStub("LibActionButton-1.0-ElvUI")
		ActionBarSystem = "LAB"
	elseif Dominos then
		ActionBarSystem = "Dominos"
	else
		ActionBarSystem = "Blizzard"
    end

    MegaMacroIconEvaluator.OnIconUpdated(function()
        rangeTimer = -1
    end)
end

function MegaMacroActionBarEngine.OnUpdate(elapsed)
    UpdateRangeTimer(elapsed)

    local focus = GetMouseFocus()
	local iterator = ForEachBlizzardActionButton
	
	if ActionBarSystem == "LAB" then
		iterator = ForEachLibActionButton
	elseif ActionBarSystem == "Dominos" then
		iterator = ForEachDominosButton
	end

	iterator(function(button)
		local action = button:GetAttribute("action") or button.action
        local type, actionArg1 = GetActionInfo(action)
        local macroId = type == "macro" and MegaMacroEngine.GetMacroIdFromIndex(actionArg1)

		if macroId then
			ActionsBoundToMegaMacros[button] = true
            UpdateActionBar(button, macroId)

            if button == focus then
                ShowToolTipForMegaMacro(macroId)
			end
		elseif ActionsBoundToMegaMacros[button] then
			ActionsBoundToMegaMacros[button] = nil
			if not actionArg1 then
				-- was a mega macro, now unbound, make sure to reset a few values
				ResetActionBar(button)
			end
		end
    end)
end

function MegaMacroActionBarEngine.OnTargetChanged()
    rangeTimer = -1
end

hooksecurefunc("ActionButton_UpdateRangeIndicator", function()
	rangeTimer = -1
end)