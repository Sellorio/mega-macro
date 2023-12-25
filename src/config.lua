function MegaMacro_InitialiseConfig()
    if MegaMacroGlobalData == nil then
        MegaMacroGlobalData = {
            Activated = false,
            Macros = {},
            InactiveMacros = {},
            Classes = {}
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
            UseNativeActionBar = false,
        }
    end
    if MegaMacroBackup == nil then
        MegaMacroBackup = {
            Global = {},
            Characters = {},
            BackUpTime = 0
        }
    end
end

function MegaMacroConfig_IsWindowDialog()
    return not MegaMacroGlobalData.WindowInfo and true or MegaMacroGlobalData.WindowInfo.IsDialog
end

function MegaMacroConfig_GetWindowPosition()
    if MegaMacroGlobalData.WindowInfo then
        return MegaMacroGlobalData.WindowInfo.RelativePoint, MegaMacroGlobalData.WindowInfo.X, MegaMacroGlobalData.WindowInfo.Y
    end
end

