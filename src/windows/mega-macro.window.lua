local macroLimits = {
	Size = 1024,
	-- limit: 120 non-character specific macro slots
	GlobalCount = 70,
	PerClassCount = 25,
	PerSpecializationCount = 25,
	-- limit: 18 character specific macro slots
	PerCharacterCount = 8,
	PerCharacterSpecializationCount = 10
}

local macroStartIndexes = {
	Global = 1,
	PerClass = 1 + macroLimits.GlobalCount,
	PerSpecialization = 1 + macroLimits.GlobalCount + macroLimits.PerClassCount,
	-- restarting index due to different macro scope
	PerCharacter = 1,
	PerCharacterSpecialization = 1 + macroLimits.PerCharacterCount
}

NUM_MACROS_PER_ROW = 12;
NUM_ICONS_PER_ROW = 10;
NUM_ICON_ROWS = 9;
NUM_MACRO_ICONS_SHOWN = NUM_ICONS_PER_ROW * NUM_ICON_ROWS;
MACRO_ICON_ROW_HEIGHT = 36;
MEGAMACROFRAME_CHAR_LIMIT = "%s/%s Characters Used"

UIPanelWindows["MegaMacro_Frame"] = { area = "left", pushable = 1, whileDead = 1, width = PANEL_DEFAULT_WIDTH + 302 };

StaticPopupDialogs["CONFIRM_DELETE_SELECTED_MACRO"] = {
	text = CONFIRM_DELETE_MACRO,
	button1 = OKAY,
	button2 = CANCEL,
	OnAccept = function(self)
        -- delete mega macro here
	end,
	timeout = 0,
	whileDead = 1,
	showAlert = 1
};

local function Show()
    ShowUIPanel(MegaMacro_Frame);
end

function MegaMacro_Window_OnLoad()
    -- Global, Class, ClassSpec, Character, CharacterSpec
	PanelTemplates_SetNumTabs(MegaMacro_Frame, 5);
	PanelTemplates_SetTab(MegaMacro_Frame, 1);
end

function MegaMacro_Window_OnShow()
end

function MegaMacro_Window_OnHide()
    MegaMacro_PopupFrame:Hide();
end

function MegaMacro_ButtonContainer_OnLoad(self)
	local button;
	local maxMacroButtons = max(MAX_ACCOUNT_MACROS, MAX_CHARACTER_MACROS);
	for i=1, maxMacroButtons do
		button = CreateFrame("CheckButton", "MegaMacro_MacroButton"..i, self, "MegaMacro_ButtonTemplate");
		button:SetID(i);
		if i == 1 then
			button:SetPoint("TOPLEFT", self, "TOPLEFT", 6, -6);
		elseif mod(i, NUM_MACROS_PER_ROW) == 1 then
			button:SetPoint("TOP", "MegaMacro_MacroButton"..(i-NUM_MACROS_PER_ROW), "BOTTOM", 0, -10);
		else
			button:SetPoint("LEFT", "MegaMacro_MacroButton"..(i-1), "RIGHT", 13, 0);
		end
	end
end

function MegaMacro_EditButton_OnClick(self, button)
end

function MegaMacro_TextBox_TextChanged(self)
    MegaMacro_Frame.textChanged = 1;

    if MegaMacro_PopupFrame.mode == "new" then
        MegaMacro_PopupFrame:Hide();
    end

    MegaMacro_FrameCharLimitText:SetFormattedText(MEGAMACROFRAME_CHAR_LIMIT, MegaMacro_FrameText:GetNumLetters(), macroLimits.Size);

    ScrollingEdit_OnTextChanged(self, self:GetParent());
end

function MegaMacro_CancelButton_OnClick()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	MegaMacro_PopupFrame:Hide();
	MegaMacro_FrameText:ClearFocus();
end

function MegaMacro_SaveButton_OnClick()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	MegaMacro_PopupFrame:Hide();
	MegaMacro_FrameText:ClearFocus();
end

function MegaMacro_NewButton_OnClick()
	MegaMacro_PopupFrame.mode = "new";
	MegaMacro_PopupFrame:Show();
end

function MegaMacro_EditOkButton_OnClick()
    -- create/update editted macro
	MegaMacro_PopupFrame:Hide();
end

function MegaMacro_EditCancelButton_OnClick()
	MegaMacro_PopupFrame:Hide();
	MegaMacro_PopupFrame.selectedIcon = nil;
end

MegaMacroWindow = {
    Show = function()
        ShowUIPanel(MegaMacro_Frame);
    end
}