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

-- This was missing or deleted, causing the error:
function MegaMacroConfig_IsWindowDialog()
    -- If WindowInfo is nil, default to Dialog mode (true)
    if not MegaMacroGlobalData or not MegaMacroGlobalData.WindowInfo then
        return true
    end
    return MegaMacroGlobalData.WindowInfo.IsDialog
end

-- This is also needed for the window to remember its location:
function MegaMacroConfig_GetWindowPosition()
    if MegaMacroGlobalData and MegaMacroGlobalData.WindowInfo then
        return MegaMacroGlobalData.WindowInfo.RelativePoint, MegaMacroGlobalData.WindowInfo.X, MegaMacroGlobalData.WindowInfo.Y
    end
    -- Return default center position if no data exists
    return "CENTER", 0, 0
end