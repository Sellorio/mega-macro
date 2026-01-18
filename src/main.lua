-------------------------------------------------------------------
-- MEGAMACRO COMPATIBILITY SHIM (WoW 11.x / 12.x)
-------------------------------------------------------------------
-- This fixes "nil value" errors caused by Blizzard's API refactor.
-- We inject these into the Global (_G) and C_Spell tables.

local function ModernIsOverlayed(spellID)
    if not spellID then return false end
    -- 11.0+ uses the specialized C_SpellActivationOverlay namespace
    if C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed then
        return C_SpellActivationOverlay.IsSpellOverlayed(spellID)
    end
    return false
end

local function ModernHideGlow(self)
    if not self then return end
    if self.SpellHighlightTexture then self.SpellHighlightTexture:Hide() end
    if SharedActionButton_RefreshSpellHighlight then
        SharedActionButton_RefreshSpellHighlight(self, false)
    end
end

local function ModernShowGlow(self)
    if not self then return end
    if self.SpellHighlightTexture then self.SpellHighlightTexture:Show() end
    if SharedActionButton_RefreshSpellHighlight then
        SharedActionButton_RefreshSpellHighlight(self, true)
    end
end

local function ModernClearCharges(self)
    if not self then return end
    if self.chargeCooldown then self.chargeCooldown:Clear() end
    if self.cooldown then self.cooldown:Clear() end
end

-- 1. Apply to Global Namespace
_G.IsOverlayed = ModernIsOverlayed
_G.ActionButton_HideOverlayGlow = ModernHideGlow
_G.ActionButton_ShowOverlayGlow = ModernShowGlow
_G.ClearChargeCooldown = ModernClearCharges

-- 2. Apply to C_Spell Namespace (Fixes "field" errors in engine.lua)
if _G.C_Spell then
    _G.C_Spell.IsOverlayed = ModernIsOverlayed
    _G.C_Spell.GetSpellConfirmationOverlay = ModernIsOverlayed
end

-- 3. Apply to C_SpellActivationOverlay (Fallback injection)
if not _G.C_SpellActivationOverlay then _G.C_SpellActivationOverlay = {} end
if not _G.C_SpellActivationOverlay.GetOverlayInfo then
    _G.C_SpellActivationOverlay.GetOverlayInfo = ModernIsOverlayed
end

-------------------------------------------------------------------
-- END SHIM
-------------------------------------------------------------------

MegaMacroCachedClass = nil
MegaMacroCachedSpecialization = nil
MegaMacroFullyActive = false
MegaMacroSystemTime = GetTime()

local f = CreateFrame("Frame", "MegaMacro_EventFrame", UIParent)
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LEAVING_WORLD")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("PLAYER_TARGET_CHANGED")

local function OnUpdate(_, elapsed)
    MegaMacroSystemTime = GetTime()
    local elapsedMs = elapsed * 1000
    MegaMacroIconNavigator.OnUpdate()
    if MegaMacroConfig['UseNativeActionBar'] and not MegaMacro_Frame:IsVisible() then
		return
	end
    MegaMacroIconEvaluator.Update(elapsedMs)
    MegaMacroActionBarEngine.OnUpdate(elapsed)
end

local function Initialize()
    MegaMacro_InitialiseConfig()
    MegaMacroIconNavigator.BeginLoadingIcons()

    SLASH_Mega1 = "/m"
    SLASH_Mega2 = "/macro"
    SlashCmdList["Mega"] = function()
        MegaMacroWindow.Show()

        if not MegaMacroFullyActive then
            ShowMacroFrame()
        end
    end

    local specIndex = GetSpecialization()
    if specIndex then
        MegaMacroCachedClass = UnitClass("player")
        MegaMacroCachedSpecialization = select(2, GetSpecializationInfo(specIndex))

        MegaMacroCodeInfo.ClearAll()
        MegaMacroIconEvaluator.Initialize()
        MegaMacroActionBarEngine.Initialize()
        MegaMacroEngine.SafeInitialize()
        MegaMacroEngine.ImportMacros()
        MegaMacroEngine.VerifyMacros()
        MegaMacroFullyActive = MegaMacroGlobalData.Activated and MegaMacroCharacterData.Activated
        f:SetScript("OnUpdate", OnUpdate)
    end
end

f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        Initialize()
    elseif event == "PLAYER_LEAVING_WORLD" then
        f:SetScript("OnUpdate", nil)
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        MegaMacroWindow.SaveMacro()

        local oldValue = MegaMacroCachedSpecialization
        MegaMacroCachedSpecialization = select(2, GetSpecializationInfo(GetSpecialization()))

        MegaMacroCodeInfo.ClearAll()
        MegaMacroIconEvaluator.ResetCache()

        if not InCombatLockdown() then -- this event triggers when levelling up too - in combat we don't want it to cause errors
            MegaMacroEngine.OnSpecializationChanged(oldValue, MegaMacroCachedSpecialization)
            MegaMacroWindow.OnSpecializationChanged(oldValue, MegaMacroCachedSpecialization)
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        MegaMacroActionBarEngine.OnTargetChanged()
    end
end)

MegaMacro_RegisterShiftClicks()

tinsert(UISpecialFrames, "MegaMacro_Frame")
UIPanelWindows["MegaMacro_Frame"] = nil