function MegaMacro_InitialiseConfig()
    if MegaMacroGlobalData == nil then
        MegaMacroGlobalData = {
            Activated = false,
            Macros = {},
            Classes = {}
            -- Macro: { class, spezialization, displayName, code }
        }
    end

    if MegaMacroCharacterData == nil then
        MegaMacroCharacterData = {
            Enabled = false,
            Macros = {},
            Specializations = {}
            -- Macro: { spezialization, displayName, code }
        }
    end
end

--[[
MegaMacroGlobalData = {
    Activated = false,                                          Whether or not the addon is activated in a global scope - copies global macros from native and replaces with mega macros
    Macros = {
        [1] = {
            Id = "DisplayNgg01",                                DisplayName is truncated to 8 characters, padded where needed with spaces and then the scope code is added with the index of the native macro within the scope
            DisplayName = "DisplayName",
            Code = "code"
        }
    },
    Classes = {
        ["Druid"] = {
            Macros = {
                [1] = {
                    Id = "DisplayNgg01",
                    DisplayName = "DisplayName",
                    Code = "code"
                }
            },
            Specializations = {
                ["Restoration"] = {
                    Macros = {
                        [1] = {
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
        [1] = {
            Id = "DisplayNgg01",
            DisplayName = "DisplayName",
            Code = "code"
        }
    },
    Specializations = {
        ["Restoration"] = {
            Macros = {
                [1] = {
                    Id = "DisplayNgg01",
                    DisplayName = "DisplayName",
                    Code = "code"
                }
            }
        }
    }
}
]]