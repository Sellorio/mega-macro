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
 - Count (spells or items).
 - Charges (spells only atm)
 - Spell Glow (such as on empowerments for Balance Druid)
 - Active Auto Attack Flash (flashes red when auto attack is active) - intentionally omitted from this addon

]]

local LibActionButton = nil
local ActionBarSystem = nil -- Blizzard or LAB or Dominos
local BlizzardActionBars = { "Action", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7" }

local rangeTimer = 5
local updateRange = false

local ActionsBoundToMegaMacros = {}

-- Cache that remembers the last macro ID and modifier state for each button.
local buttonCache = {}   -- [button] = { macroId = number|nil, mods = "SCA"|"" }

-- Global snapshot of the modifier signature from the previous OnUpdate tick.
local previousGlobalMods = ""

-- [[ 12.0 COMPATIBILITY HELPERS ]] --

-- Helper: Safe GetActionInfo
local function GetActionInfo(slot)
    if C_ActionBar and C_ActionBar.GetActionInfo then
        return C_ActionBar.GetActionInfo(slot)
    end
    return _G.GetActionInfo(slot)
end

-- Helper: Safe GetMacroInfo
local function GetMacroInfo(index)
    if C_Macro and C_Macro.GetMacroInfo then
        local info = C_Macro.GetMacroInfo(index)
        if info then
            return info.name, info.icon, info.body, info.isLocal
        end
    end
    if _G.GetMacroInfo then
        return _G.GetMacroInfo(index)
    end
end

-- Helper: Polyfill for ActionButton_ShowOverlayGlow (Removed in 12.0)
local function Safe_ShowOverlayGlow(button)
    if ActionButton_ShowOverlayGlow then
        ActionButton_ShowOverlayGlow(button)
    elseif button.ShowOverlayGlow then
        button:ShowOverlayGlow()
    elseif LCG then -- LibButtonGlow fallback
        LCG.ShowOverlayGlow(button)
    end
end

-- Helper: Polyfill for ActionButton_HideOverlayGlow (Removed in 12.0)
local function Safe_HideOverlayGlow(button)
    if ActionButton_HideOverlayGlow then
        ActionButton_HideOverlayGlow(button)
    elseif button.HideOverlayGlow then
        button:HideOverlayGlow()
    elseif LCG then -- LibButtonGlow fallback
        LCG.HideOverlayGlow(button)
    end
end

-- Helper: Polyfill for CooldownFrame_Set (Removed in 11.0/12.0)
local function Safe_CooldownFrame_Set(self, start, duration, enable, forceShowDrawEdge, modRate)
    if _G.CooldownFrame_Set then
        _G.CooldownFrame_Set(self, start, duration, enable, forceShowDrawEdge, modRate)
    elseif self.SetCooldown then
        if enable then
            self:SetCooldown(start, duration, modRate)
            if forceShowDrawEdge and self.SetDrawEdge then
                self:SetDrawEdge(true)
            end
        else
            self:Hide()
        end
    end
end

-- [[ END HELPERS ]] --

local function UpdateCurrentActionState(button, functions, abilityId)
    local isChecked = functions.IsCurrent(abilityId) or functions.IsAutoRepeat(abilityId)

    if not isChecked and functions == MegaMacroInfoFunctions.Spell then
        local shapeshiftFormIndex = GetShapeshiftForm()
        if shapeshiftFormIndex and shapeshiftFormIndex > 0 then
            -- 12.0 Compatibility for Shapeshift info
            local stanceSpellID
            if C_ShapeshiftForm then
                local _, _, _, id = C_ShapeshiftForm.GetShapeshiftFormInfo(shapeshiftFormIndex)
                stanceSpellID = id
            else
                local _, _, _, id = GetShapeshiftFormInfo(shapeshiftFormIndex)
                stanceSpellID = id
            end
            
            if abilityId == stanceSpellID then
                isChecked = true
            end
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
        return
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
end

local function LibActionButton_EndChargeCooldown(self)
    self:Hide()
    self:SetParent(UIParent)

    if self.parent then
        self.parent.chargeCooldown = nil
        self.parent = nil
    end

    if not LibActionButton.ChargeCooldowns then
        LibActionButton.ChargeCooldowns = {}
    end
    tinsert(LibActionButton.ChargeCooldowns, self)
end

local function LibActionButton_StartChargeCooldown(parent, chargeStart, chargeDuration, chargeModRate)
    if not LibActionButton.ChargeCooldowns then
        LibActionButton.ChargeCooldowns = {}
    end
    if not LibActionButton.NumChargeCooldowns then
        LibActionButton.NumChargeCooldowns = 0
    end

    if not parent.chargeCooldown then
        local cooldown = tremove(LibActionButton.ChargeCooldowns)
        if not cooldown then
            LibActionButton.NumChargeCooldowns = LibActionButton.NumChargeCooldowns + 1
            cooldown = CreateFrame(
                "Cooldown",
                "LAB10ChargeCooldown"..LibActionButton.NumChargeCooldowns,
                parent,
                "CooldownFrameTemplate"
            )
            cooldown:SetScript("OnCooldownDone", LibActionButton_EndChargeCooldown)
        end

        cooldown.parent = parent
        cooldown:SetHideCountdownNumbers(false)
        cooldown:SetDrawSwipe(true)
        cooldown:SetEdgeTexture("Interface\\Cooldown\\edge")
        cooldown:SetSwipeColor(0, 0, 0)

        cooldown:SetParent(parent)
        cooldown:SetAllPoints(parent)
        cooldown:SetFrameStrata("TOOLTIP")
        cooldown:Show()

        parent.chargeCooldown = cooldown
    end

    parent.chargeCooldown:SetDrawBling(parent.chargeCooldown:GetEffectiveAlpha() > 0.5)
    Safe_CooldownFrame_Set(parent.chargeCooldown, chargeStart, chargeDuration, true, true, chargeModRate)

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
        Safe_CooldownFrame_Set(button.cooldown, locStart, locDuration, true, true, modRate)
    else
        if button.cooldown.currentCooldownType ~= COOLDOWN_TYPE_NORMAL then
            button.cooldown:SetEdgeTexture("Interface\\Cooldown\\edge")
            button.cooldown:SetSwipeColor(0, 0, 0)
            button.cooldown:SetHideCountdownNumbers(false)
            button.cooldown.currentCooldownType = COOLDOWN_TYPE_NORMAL
        end

        if locStart > 0 then
            button.cooldown:SetScript("OnCooldownDone",
                function() UpdateCooldownLibActionButton(button, functions, abilityId) end)
        end

        local hasCharges = charges and maxCharges and maxCharges > 1
        if hasCharges and charges > 0 and charges < maxCharges then
            Safe_CooldownFrame_Set(button.cooldown, chargeStart, chargeDuration, true, false, chargeModRate)
            button.cooldown:SetEdgeTexture("Interface\\Cooldown\\edge")
            button.cooldown:SetSwipeColor(0, 0, 0)
            button.cooldown:SetHideCountdownNumbers(false)
        else
            button.cooldown:SetCooldown(0, 0)
        end

        Safe_CooldownFrame_Set(button.cooldown, start, duration, enable, false, modRate)
    end
end

local function UpdateCooldownBlizzard(button, functions, abilityId)
    local locStart, locDuration = functions.GetLossOfControlCooldown(abilityId)
    local start, duration, enable, modRate = functions.GetCooldown(abilityId)
    local charges, maxCharges, chargeStart, chargeDuration, chargeModRate = functions.GetCharges(abilityId)

    if ( (locStart + locDuration) > (start + duration) ) then
        if ( button.cooldown.currentCooldownType ~= COOLDOWN_TYPE_LOSS_OF_CONTROL ) then
            button.cooldown:SetEdgeTexture("Interface\\Cooldown\\edge-LoC")
            button.cooldown:SetSwipeColor(0.17, 0, 0)
            button.cooldown:SetHideCountdownNumbers(true)
            button.cooldown.currentCooldownType = COOLDOWN_TYPE_LOSS_OF_CONTROL
        end

        Safe_CooldownFrame_Set(button.cooldown, locStart, locDuration, true, true, modRate)
        if ClearChargeCooldown then ClearChargeCooldown(button) end
    else
        if ( button.cooldown.currentCooldownType ~= COOLDOWN_TYPE_NORMAL ) then
            button.cooldown:SetEdgeTexture("Interface\\Cooldown\\edge")
            button.cooldown:SetSwipeColor(0, 0, 0)
            button.cooldown:SetHideCountdownNumbers(false)
            button.cooldown.currentCooldownType = COOLDOWN_TYPE_NORMAL
        end

        if( locStart > 0 ) then
            -- 12.0 Safety: Check if handler exists
            if ActionButton_OnCooldownDone then
                button.cooldown:SetScript("OnCooldownDone", ActionButton_OnCooldownDone)
            end
        end

        if ( charges and maxCharges and maxCharges > 1 and charges < maxCharges ) then
            if StartChargeCooldown then
                StartChargeCooldown(button, chargeStart, chargeDuration, chargeModRate)
            end
        else
            if ClearChargeCooldown then ClearChargeCooldown(button) end
        end

        Safe_CooldownFrame_Set(button.cooldown, start, duration, enable, false, modRate)
    end
end

local function UpdateCount(button, functions, abilityId)
    local countLabel = button.Count
    local count = functions.GetCount(abilityId)

    local isNonEquippableItem = functions == MegaMacroInfoFunctions.Item and not C_Item.IsEquippableItem(abilityId)
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
        Safe_ShowOverlayGlow(button)
    else
        Safe_HideOverlayGlow(button)
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
    
    -- Optimized: Set timer based on state to reduce checks
    rangeTimer = 1;

    local hotkeyUpdated = false
    if Bartender4 then
        if checksRange and not inRange then
            if Bartender4.db.profile.outofrange == "button" then
                button.icon:SetVertexColor(
                    Bartender4.db.profile.colors.range.r,
                    Bartender4.db.profile.colors.range.g,
                    Bartender4.db.profile.colors.range.b)
            elseif Bartender4.db.profile.outofrange == "hotkey" then
                button.HotKey:SetVertexColor(
                    Bartender4.db.profile.colors.range.r,
                    Bartender4.db.profile.colors.range.g,
                    Bartender4.db.profile.colors.range.b)
            end
            return
        end
    end

    if button.HotKey:GetText() == RANGE_INDICATOR then
        if checksRange then
            button.HotKey:Show();
            if ( inRange ) then
                button.HotKey:SetVertexColor(LIGHTGRAY_FONT_COLOR:GetRGB());
            elseif not hotkeyUpdated then
                button.HotKey:SetVertexColor(RED_FONT_COLOR:GetRGB());
            end
        else
            button.HotKey:Hide();
        end
    else
        if checksRange and not inRange and not hotkeyUpdated then
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

        -- Range updates can be expensive, throttle handled by OnUpdate logic
        UpdateRange(button, functions, data.Id, data.Target)
    end
end

local function ResetActionBar(button)
    button:SetChecked(false)
    button.Count:SetText("")
    button.Border:Hide() 
    Safe_HideOverlayGlow(button)
    if ClearChargeCooldown then ClearChargeCooldown(button) end
    UpdateRange(button, MegaMacroInfoFunctions.Unknown)
    button.icon:SetVertexColor(1.0, 1.0, 1.0) 

    local normalTexture = button.NormalTexture
    if normalTexture then
        normalTexture:SetVertexColor(1.0, 1.0, 1.0)
    end
end

local function ForEachLibActionButton(func)
    if LibActionButton and LibActionButton.buttonRegistry then
        for button, _ in pairs(LibActionButton.buttonRegistry) do
            func(button)
        end
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

-- Returns a short string that uniquely represents the current modifier key state.
local function GetCurrentModifierSignature()
    local sig = ""
    if IsShiftKeyDown()    then sig = sig .. "S" end
    if IsControlKeyDown() then sig = sig .. "C" end
    if IsAltKeyDown()      then sig = sig .. "A" end
    return sig
end

function MegaMacroActionBarEngine.OnUpdate(elapsed)
    UpdateRangeTimer(elapsed)

    local currentGlobalMods = GetCurrentModifierSignature()
    if currentGlobalMods ~= previousGlobalMods then
        for btn, _ in pairs(buttonCache) do
            buttonCache[btn] = nil
        end
        previousGlobalMods = currentGlobalMods
    end

    local focus = GetMouseFoci and GetMouseFoci()[1] or GetMouseFocus and GetMouseFocus()
    local iterator = ForEachBlizzardActionButton

    if ActionBarSystem == "LAB" then
        iterator = ForEachLibActionButton
    elseif ActionBarSystem == "Dominos" then
        iterator = ForEachDominosButton
    end

    iterator(function(button)
        local action = button:GetAttribute("action") or button.action
        if not action then return end

        local type, id = GetActionInfo(action)
        
        -- 12.0 Fix: C_Macro.GetMacroBody is removed. Use GetMacroInfo(id) to get body.
        local macroCode = nil
        if type == "macro" and id then
            local _, _, body = GetMacroInfo(id)
            macroCode = body
        end

        local macroId = nil
        if type == "macro" and macroCode and _G.type(macroCode) == "string" and #macroCode >= 4 then
            macroId = tonumber(string.sub(macroCode, 2, 4))
        end

        local needRefresh = false
        local curMods     = GetCurrentModifierSignature()

        if macroId then
            local cache = buttonCache[button]
            if not cache then
                cache = { macroId = nil, mods = nil }
                buttonCache[button] = cache
            end

            if cache.macroId ~= macroId or cache.mods ~= curMods then
                needRefresh = true
                cache.macroId = macroId
                cache.mods    = curMods
            end
        else
            if buttonCache[button] then
                buttonCache[button] = nil
            end
            needRefresh = false
        end

        if macroId and needRefresh then
            ActionsBoundToMegaMacros[button] = true
            UpdateActionBar(button, macroId)

            if button == focus then
                ShowToolTipForMegaMacro(macroId)
            end
        elseif ActionsBoundToMegaMacros[button] then
            ActionsBoundToMegaMacros[button] = nil
            -- arg1 is legacy, checking type/id is enough usually
            ResetActionBar(button)
        end
    end)
end

function MegaMacroActionBarEngine.OnTargetChanged()
    rangeTimer = -1
end

if hooksecurefunc then
    hooksecurefunc("ActionButton_UpdateRangeIndicator", function()
        rangeTimer = -1
    end)
end