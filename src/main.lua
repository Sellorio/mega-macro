local function OnUpdate(_, elapsed)
    local elapsedMs = elapsed * 1000
    MegaMacroIconEvaluator.Update(elapsedMs)
end

local f = CreateFrame("Frame", "MegaMacro_EventFrame", UIParent)
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ALIVE")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "MegaMacro" or event == "PLAYER_ALIVE" then
        MegaMacro_InitialiseConfig()
        MegaMacro_InitialiseMacroEngine()

        SLASH_Mega1 = "/mega"
        SlashCmdList["Mega"] = MegaMacroWindow.Show

        if GetSpecialization() then
            self:SetScript("OnUpdate", OnUpdate)
            MegaMacroIconEvaluator.Initialize()
        end
    end
end)
