local f = CreateFrame("Frame", "MegaMacroLoadedFrame", UIParent)
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(frame, event, arg1, ...)
    if arg1 == "MegaMacro" then
        f:UnregisterEvent("ADDON_LOADED")

        MegaMacro_InitialiseConfig()
        MegaMacro_InitialiseMacroEngine()

        SLASH_Mega1 = "/mega"
        SlashCmdList["Mega"] = MegaMacroWindow.Show
    end
end)

