function MegaMacro_InitialiseConfig()
    -- New: Keep track of the addon data version
    local currentDataVersion = 120 -- Corresponds to 12.0
    
    if MegaMacroGlobalData == nil then
        MegaMacroGlobalData = {
            Activated = false,
            Macros = {},
            InactiveMacros = {},
            Classes = {},
            Version = currentDataVersion -- Added versioning
        }
    end

    if MegaMacroCharacterData == nil then
        MegaMacroCharacterData = {
            Activated = false,
            Macros = {},
            Specializations = {}
        }
    end

    if MegaMacroConfig == nil then
        MegaMacroConfig = {
            UseNativeActionBar = true,
            -- New: Default UI transparency for 12.0 HUD
            WindowOpacity = 1.0, 
        }
    end
end