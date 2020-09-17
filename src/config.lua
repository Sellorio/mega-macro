function MegaMacro_InitialiseConfig()
    if MegaMacroConfig == nil then
        MegaMacroConfig = {
        }

        MegaMacroGlobalData = {
            Macros = {}
            -- Macro: { class, spezialization, displayName, code }
        }
    end

    if MegaMacroCharacterData == nil then
        MegaMacroCharacterData = {
            Enabled = false,
            Macros = {}
            -- Macro: { spezialization, displayName, code }
        }
    end
end