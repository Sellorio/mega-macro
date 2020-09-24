MegaMacroCachedClass = nil
MegaMacroCachedSpecialization = nil

local f = CreateFrame("Frame", "MegaMacro_EventFrame", UIParent)
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LEAVING_WORLD")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

local function OnUpdate(_, elapsed)
    local elapsedMs = elapsed * 1000
    MegaMacroIconEvaluator.Update(elapsedMs)
end

local function Initialize()
    MegaMacro_InitialiseConfig()

    SLASH_Mega1 = "/mega"
    SlashCmdList["Mega"] = MegaMacroWindow.Show

    local specIndex = GetSpecialization()
    if specIndex then
        MegaMacroCachedClass = UnitClass("player")
        MegaMacroCachedSpecialization = select(2, GetSpecializationInfo(specIndex))

        MegaMacroIconEvaluator.Initialize()
        MegaMacroEngine.SafeInitialize()
        f:SetScript("OnUpdate", OnUpdate)
    end
end

f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "MegaMacro" then
            Initialize()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        Initialize()
    elseif event == "PLAYER_LEAVING_WORLD" then
        f:SetScript("OnUpdate", nil)
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        MegaMacroWindow.SaveMacro()

        local oldValue = MegaMacroCachedSpecialization
        MegaMacroCachedSpecialization = select(2, GetSpecializationInfo(GetSpecialization()))

        MegaMacroCodeInfo.ClearAll()
        MegaMacroIconEvaluator.ResetCache()
        MegaMacroEngine.OnSpecializationChanged(oldValue, MegaMacroCachedSpecialization)
        MegaMacroWindow.OnSpecializationChanged(oldValue, MegaMacroCachedSpecialization)
    end
end)
