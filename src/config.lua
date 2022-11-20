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

    if MegaMacroConfig == nil then
        MegaMacroConfig = {
            UseNativeMacros = false,
            MaxMacroLength = MegaMacroCodeMaxLength,
            UseNativeActionBarIcon = false,
        }
    end

    MegaMacroConfig['MaxMacroLength'] = MegaMacroConfig['UseNativeMacros'] and 250 or MegaMacroCodeMaxLength
end

function MegaMacroConfig_IsWindowDialog()
    return not MegaMacroGlobalData.WindowInfo and true or MegaMacroGlobalData.WindowInfo.IsDialog
end

function MegaMacroConfig_GetWindowPosition()
    if MegaMacroGlobalData.WindowInfo then
        return MegaMacroGlobalData.WindowInfo.RelativePoint, MegaMacroGlobalData.WindowInfo.X, MegaMacroGlobalData.WindowInfo.Y
    end
end

-- Create the Config options
function MecaMacro_GenerateConfig()
    -- Blizzard Macro option
    MecaMacroConfig_GenerateCheckbox('UseBlizzardMacros', 'Blizzard Style Macros', '250 Char limit. \nUses Blizzards Macro Buttons while keeping MegaMacro interface and organizer. \n\nEnable this if you have stability issues or need to uninstall MegaMacro. \n\nNote: Uninstalling may still cause you to lose class and spec Macros since they are not supported by Blizzard. Move them to global or character tabs before uninstalling.', 0, 0, MegaMacroConfig.UseNativeMacros, function(value) 
        MegaMacroConfig.UseNativeMacros = value
        MegaMacro_BlizMacro_Toggle()
    end)
    -- Blizzard Action Bar Icons
    MecaMacroConfig_GenerateCheckbox('UseBlizzardActionIcons', 'Blizzard Action Bar Icons', 'Disable Mega Macro Action Bar Engine. \nOnly Use with Blizzard Style Macros', 0, -25, MegaMacroConfig.UseNativeActionBarIcon, function(value) 
        MegaMacroConfig.UseNativeActionBarIcon = value
    end)
end

function MecaMacroConfig_GenerateCheckbox(name, text, tooltip, x, y, checked, onClick)
    local checkbox = CreateFrame("CheckButton", "MegaMacro_ConfigContainer_" .. name, MegaMacro_ConfigContainer, "ChatConfigCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", x, y)
    checkbox:SetChecked(checked)
    checkbox:SetScript("OnClick", function(self)
        onClick(checkbox:GetChecked())
    end)
    checkbox.tooltip = tooltip
    
    local textFrame = _G[checkbox:GetName() .. "Text"]
    textFrame:SetFontObject("GameFontNormalSmall")
    textFrame:SetText(text)

    return checkbox
end