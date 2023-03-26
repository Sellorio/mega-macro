MegaMacroCachedClass = nil
MegaMacroCachedSpecialization = nil
MegaMacroFullyActive = false
MegaMacroUpdateInterval = 0.01 -- 10ms
MegaMacroShiftClicksRegistered = false

local function MegaMacroOnUpdate(self, elapsed)
    -- Load icons if EnableIconLoading has been called
    MegaMacroIconNavigator.LoadIcons()

    -- Don't update rest if native action bar is active
    if MegaMacroConfig["UseNativeActionBar"] and not MegaMacro_Frame:IsVisible() then
        return
    end

    -- Limit update rate to fixed interval
    -- self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed;
    -- while (self.TimeSinceLastUpdate > MegaMacroUpdateInterval) do
    --     self.TimeSinceLastUpdate = self.TimeSinceLastUpdate - MegaMacroUpdateInterval;
    -- end
    MegaMacroActionBarEngine.Update(elapsed)
    MegaMacroIconEvaluator.Update(elapsed)
end

function MegaMacroOnEvent(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        MegaMacro_InitialiseConfig()

        -- Enable icon loading
        MegaMacroIconNavigator.EnableIconLoading()

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

            self:SetScript("OnUpdate", MegaMacroOnUpdate)
        end
        if not MegaMacroShiftClicksRegistered then
            MegaMacro_RegisterShiftClicks()
            MegaMacroShiftClicksRegistered = true
        end
    elseif event == "PLAYER_LEAVING_WORLD" then
        self:SetScript("OnUpdate", nil)
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
end
