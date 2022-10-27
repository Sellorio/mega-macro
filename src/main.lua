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
    MegaMacroIconEvaluator.Update(elapsedMs)
    MegaMacroActionBarEngine.OnUpdate(elapsed)
    MegaMacroIconNavigator.OnUpdate()
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
