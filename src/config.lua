function MegaMacro_InitialiseConfig()
    if MegaMacroGlobalData == nil then
        MegaMacroGlobalData = {
            Activated = false,
            Macros = {},
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
end

--[[
MegaMacroGlobalData = {
    Activated = false,                                          Whether or not the addon is activated in a global scope - copies global macros from native and replaces with mega macros
    Macros = {
        {
            Id = "DisplayNgg01",                                DisplayName is truncated to 8 characters, padded where needed with spaces and then the scope code is added with the index of the native macro within the scope
            DisplayName = "DisplayName",
            Code = "code"
        }
    },
    Classes = {
        ["Druid"] = {
            Macros = {
                {
                    Id = "DisplayNgg01",
                    DisplayName = "DisplayName",
                    Code = "code"
                }
            },
            Specializations = {
                ["Restoration"] = {
                    Macros = {
                        {
                            Id = "DisplayNgg01",
                            DisplayName = "DisplayName",
                            Code = "code"
                        }
                    }
                }
            }
        }
    }
}

MegaMacroCharacterData = {
    Enabled = false,
    Macros = {
        {
            Id = "DisplayNgg01",
            DisplayName = "DisplayName",
            Code = "code"
        }
    },
    Specializations = {
        ["Restoration"] = {
            Macros = {
                {
                    Id = "DisplayNgg01",
                    DisplayName = "DisplayName",
                    Code = "code"
                }
            }
        }
    }
}
]]

function MegaMacroConfig_IsWindowDialog()
    return not MegaMacroGlobalData.WindowInfo and true or MegaMacroGlobalData.WindowInfo.IsDialog
end

function MegaMacroConfig_GetWindowPosition()
    if MegaMacroGlobalData.WindowInfo then
        return MegaMacroGlobalData.WindowInfo.RelativePoint, MegaMacroGlobalData.WindowInfo.X, MegaMacroGlobalData.WindowInfo.Y
    end
end