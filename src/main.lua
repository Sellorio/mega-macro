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

-- Only the action bar engine needs these, and it doesn't run on Forever
if not MegaMacroIsForever then
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
f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("UPDATE_MACROS")

-- Forever only lets some classes choose a specialization and has dual spec on top of
-- that, so there the active talent group is used when there is no specialization name.
local function GetCurrentSpecialization()
    local isSelectionEnabled = C_SpecializationInfo.IsSpecSelectionEnabled
    local canChooseSpec = not isSelectionEnabled or isSelectionEnabled(select(3, UnitClass("player")))
    local specIndex = C_SpecializationInfo.GetSpecialization()
    local specName = canChooseSpec and specIndex and specIndex > 0 and select(2, C_SpecializationInfo.GetSpecializationInfo(specIndex))

    if specName and specName ~= "" then
        return specName
    elseif isSelectionEnabled then
        return C_SpecializationInfo.GetActiveSpecGroup() == 2 and DUAL_SPEC_SECONDARY or DUAL_SPEC_PRIMARY
    end
end

local function OnUpdate(_, elapsed)
    MegaMacroSystemTime = GetTime()
    local elapsedMs = elapsed * 1000
    MegaMacroIconNavigator.OnUpdate()
    if MegaMacroConfig['UseNativeActionBar'] and not MegaMacro_Frame:IsVisible() then
		return
	end
    if MegaMacroIsForever then
        -- Forever's macro conditionals are only evaluated for our window, outside of combat
        if not InCombatLockdown() then
            MegaMacroIconEvaluator.Update(elapsedMs)
        end
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

    local specialization = GetCurrentSpecialization()
    if specialization then
        MegaMacroCachedClass = UnitClass("player")
        MegaMacroCachedSpecialization = specialization

        MegaMacroCodeInfo.ClearAll()
        MegaMacroIconEvaluator.Initialize()
        if not MegaMacroIsForever then
            MegaMacroActionBarEngine.Initialize()
        end
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
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        local oldValue = MegaMacroCachedSpecialization
        local newValue = GetCurrentSpecialization()

        -- These events also fire during login and for changes that keep the same specialization
        if not oldValue or not newValue or oldValue == newValue then
            return
        end

        MegaMacroWindow.SaveMacro()
        MegaMacroCachedSpecialization = newValue

        MegaMacroCodeInfo.ClearAll()
        MegaMacroIconEvaluator.ResetCache()

        if not InCombatLockdown() then -- this event triggers when levelling up too - in combat we don't want it to cause errors
            MegaMacroEngine.OnSpecializationChanged(oldValue, MegaMacroCachedSpecialization)
            MegaMacroWindow.OnSpecializationChanged(oldValue, MegaMacroCachedSpecialization)
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        MegaMacroActionBarEngine.OnTargetChanged()
    elseif event == "UPDATE_MACROS" then
        MegaMacroEngine.OnNativeMacrosChanged()
    end
end)

MegaMacro_RegisterShiftClicks()

tinsert(UISpecialFrames, "MegaMacro_Frame")
UIPanelWindows["MegaMacro_Frame"] = nil