local function OnUpdate(_, elapsed)
    local elapsedMs = elapsed * 1000
    MegaMacroIconEvaluator.Update(elapsedMs)
end

local function OnAddOnLoaded()
    MegaMacro_InitialiseConfig()
    MegaMacro_InitialiseMacroEngine()

    SLASH_Mega1 = "/mega"
    SlashCmdList["Mega"] = MegaMacroWindow.Show
end

local InitializationEventsTriggered = 0

local f = CreateFrame("Frame", "MegaMacro_EventFrame", UIParent)
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ALIVE")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "MegaMacro" then
        self:UnregisterEvent("ADDON_LOADED")
        InitializationEventsTriggered = InitializationEventsTriggered + 1
        OnAddOnLoaded()
    elseif event == "PLAYER_ALIVE" then
        self:UnregisterEvent("PLAYER_ALIVE")
        InitializationEventsTriggered = InitializationEventsTriggered + 1
        MegaMacroIconEvaluator.Initialize()
    end

    if InitializationEventsTriggered == 2 then
        self:SetScript("OnUpdate", OnUpdate)
    end
end)
