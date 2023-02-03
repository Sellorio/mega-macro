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
            UseNativeActionBar = false,
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
    MecaMacroConfig_GenerateCheckbox(
        'UseBlizzardMacros',
        'Blizzard Style Macros',
        'Set Character Limit to 250.\n\nUses Blizzards Macro Buttons while keeping\nMegaMacro interface and organizer.\n\nEnable this if you have stability issues or need\nto uninstall MegaMacro.\n\nNote: Uninstalling may still cause you to lose\nclass and spec Macros since they are not\nsupported by Blizzard. Move them to global\nor character tabs before uninstalling.',
        0,
        0,
        MegaMacroConfig.UseNativeMacros,
        function(value)
            MegaMacroConfig.UseNativeMacros = value
            MegaMacro_BlizMacro_Toggle()
        end
    )
    -- Blizzard Action Bar Icons
    MecaMacroConfig_GenerateCheckbox(
        'UseBlizzardActionIcons',
        'Blizzard Action Bar Icons',
        'Disable Mega Macro Action Bar Engine.\n\nOnly Use with Blizzard Style Macros.',
        0,
        -25,
        MegaMacroConfig.UseNativeActionBar,
        function(value)
            MegaMacroConfig.UseNativeActionBar = value
        end
    )
end

function MecaMacroConfig_GenerateCheckbox(name, text, tooltipInfo, x, y, checked, onClick)
    local checkbox = CreateFrame("CheckButton", "MegaMacro_ConfigContainer_" .. name, MegaMacro_ConfigContainer, "ChatConfigCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", x, y)
    checkbox:SetChecked(checked)
    checkbox:SetScript("OnClick", function(self)
        onClick(checkbox:GetChecked())
    end)

    -- Tooltip
    checkbox:SetScript("OnEnter", function(self)
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltipInfo, 1, 1, 1)
        GameTooltip:Show()
    end)

    checkbox:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local textFrame = _G[checkbox:GetName() .. "Text"]
    textFrame:SetPoint("LEFT", checkbox, "RIGHT", 0, 0)
    textFrame:SetFontObject("GameFontNormalSmall")
    textFrame:SetText(text)

    return checkbox
end
