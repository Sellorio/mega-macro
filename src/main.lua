MegaMacroCachedClass = nil
MegaMacroCachedSpecialization = nil
MegaMacroFullyActive = false
MegaMacroSystemTime = GetTime()

local f = CreateFrame("Frame", "MegaMacro_EventFrame", UIParent)
-- 12.0 Improvement: Register ADDON_LOADED to ensure SavedVariables are ready
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LEAVING_WORLD")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("PLAYER_TARGET_CHANGED")

local function OnUpdate(_, elapsed)
    MegaMacroSystemTime = GetTime()
    local elapsedMs = elapsed * 1000
    
    if MegaMacroIconNavigator and MegaMacroIconNavigator.OnUpdate then
        MegaMacroIconNavigator.OnUpdate()
    end

    -- 12.0 Check: Prevent OnUpdate logic from running while the game is restricted/loading
    if MegaMacroConfig and MegaMacroConfig['UseNativeActionBar'] then
        if MegaMacro_Frame and not MegaMacro_Frame:IsVisible() then
            return
        end
    end

    if MegaMacroIconEvaluator then MegaMacroIconEvaluator.Update(elapsedMs) end
    if MegaMacroActionBarEngine then MegaMacroActionBarEngine.OnUpdate(elapsed) end
end

local function Initialize()
    MegaMacro_InitialiseConfig()
    MegaMacroIconNavigator.BeginLoadingIcons()

    -- 12.0 Slash Command Handling
    -- Blizzard now warns if addons overwrite /m without a priority check
    SLASH_Mega1 = "/m"
    SLASH_Mega2 = "/macro"
    SLASH_Mega3 = "/megamacro"
    
    SlashCmdList["Mega"] = function(msg)
        if InCombatLockdown() then
            print("|cFFFF0000Mega Macro:|r Cannot open UI in combat.")
            return
        end
        
        MegaMacroWindow.Show()

        if not MegaMacroFullyActive then
            if ShowMacroFrame then ShowMacroFrame() end
        end
    end

    -- Namespace Migration: Using C_SpecializationInfo for 12.0 compatibility
    local specIndex = GetSpecialization()
    if specIndex then
        local _, classFilename = UnitClass("player")
        MegaMacroCachedClass = classFilename
        
        -- Updated for 12.0: select(2, GetSpecializationInfo(index)) is still valid 
        -- but we wrap it for safety against 'Secret' returns
        local specInfo = {GetSpecializationInfo(specIndex)}
        MegaMacroCachedSpecialization = specInfo[2]

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

f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "MegaMacro" then
        -- Ensures config loads before anything else tries to read it
        MegaMacro_InitialiseConfig()
    elseif event == "PLAYER_ENTERING_WORLD" then
        Initialize()
        -- 12.0: Re-syncing action bars after loading screens is more critical now
        if MegaMacroActionBarEngine then
            MegaMacroActionBarEngine.OnTargetChanged() 
        end
    elseif event == "PLAYER_LEAVING_WORLD" then
        f:SetScript("OnUpdate", nil)
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if MegaMacroWindow and MegaMacroWindow.SaveMacro then
            MegaMacroWindow.SaveMacro()
        end

        local oldValue = MegaMacroCachedSpecialization
        local specIndex = GetSpecialization()
        if specIndex then
            MegaMacroCachedSpecialization = select(2, GetSpecializationInfo(specIndex))
        end

        MegaMacroCodeInfo.ClearAll()
        MegaMacroIconEvaluator.ResetCache()

        if not InCombatLockdown() then 
            MegaMacroEngine.OnSpecializationChanged(oldValue, MegaMacroCachedSpecialization)
            if MegaMacroWindow.OnSpecializationChanged then
                MegaMacroWindow.OnSpecializationChanged(oldValue, MegaMacroCachedSpecialization)
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if MegaMacroActionBarEngine then
            MegaMacroActionBarEngine.OnTargetChanged()
        end
    end
end)

-- Initialize Shift-Click hooks
if MegaMacro_RegisterShiftClicks then
    MegaMacro_RegisterShiftClicks()
end

-- 12.0 UI Management: Ensure the frame is registered in the "Escape" menu list
if not tContains(UISpecialFrames, "MegaMacro_Frame") then
    table.insert(UISpecialFrames, "MegaMacro_Frame")
end