local rendering = {
	MacrosPerRow = 12,
	CharLimitMessageFormat = "%s/%s Characters Used"
}

local IsOpen = false
local SelectedScope = MegaMacroScopeCodes.Global
local MacroItems = {}
local SelectedMacro = nil

NUM_ICONS_PER_ROW = 10
NUM_ICON_ROWS = 9
NUM_MACRO_ICONS_SHOWN = NUM_ICONS_PER_ROW * NUM_ICON_ROWS
MACRO_ICON_ROW_HEIGHT = 36

UIPanelWindows["MegaMacro_Frame"] = { area = "left", pushable = 1, whileDead = 1, width = PANEL_DEFAULT_WIDTH + 302 }

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
}

MegaMacroWindow = {
    Show = function()
        ShowUIPanel(MegaMacro_Frame);
	end
}

local function GetMacroButtonUI(index)
	local buttonName = "MegaMacro_MacroButton" .. index
	return _G[buttonName], _G[buttonName .. "Name"], _G[buttonName .. "Icon"]
end

-- Creates the button frames for the macro slots
local function CreateMacroSlotFrames()
	for i=1, MegaMacroHelper.HighestMaxMacroCount do
		local button = CreateFrame("CheckButton", "MegaMacro_MacroButton" .. i, MegaMacro_ButtonContainer, "MegaMacro_ButtonTemplate")
		button:SetID(i)
		if i == 1 then
			button:SetPoint("TOPLEFT", MegaMacro_ButtonContainer, "TOPLEFT", 6, -6)
		elseif mod(i, rendering.MacrosPerRow) == 1 then
			button:SetPoint("TOP", "MegaMacro_MacroButton"..(i-rendering.MacrosPerRow), "BOTTOM", 0, -10)
		else
			button:SetPoint("LEFT", "MegaMacro_MacroButton"..(i-1), "RIGHT", 13, 0)
		end
	end
end

-- Shows and hides macro slot buttons based on the number of slots available in the scope
local function InitializeMacroSlots()
	local scopeSlotCount = MegaMacroHelper.GetMacroSlotCount(SelectedScope)

	for i=1, scopeSlotCount do
		local buttonFrame = _G["MegaMacro_MacroButton" .. i]

		if buttonFrame == nil then
			break
		end

		buttonFrame:Show()
	end

	for i=scopeSlotCount+1, MegaMacroHelper.HighestMaxMacroCount do
		local buttonFrame = _G["MegaMacro_MacroButton" .. i]

		if buttonFrame == nil then
			break
		end

		buttonFrame:Hide()
	end
end

-- Sets the data for the occupied slots in the macro list
local function SetMacroItems()
	if SelectedScope == MegaMacroScopeCodes.Global then
		SetMacroItems(MegaMacroGlobalData.Macros);
	end
end

local function SaveMacro(macro)
	if SelectedMacro ~= nil then
		SelectedMacro.Code = MegaMacro_FrameText:GetText()
	end

	MegaMacro_SaveButton:Disable()
end

local function SelectMacro(macro)
	MegaMacro_FrameSelectedMacroName:SetText("")
	MegaMacro_FrameSelectedMacroButtonIcon:SetTexture("")
	MegaMacro_FrameText:SetText("")

	for i=1, MegaMacroHelper.HighestMaxMacroCount do
		local buttonFrame, buttonName, buttonIcon = GetMacroButtonUI(i)

		if macro and buttonFrame.Macro == macro then
			buttonFrame:SetChecked(true)
			SelectedMacro = macro
			MegaMacro_FrameSelectedMacroName:SetText(macro.DisplayName)
			MegaMacro_FrameSelectedMacroButtonIcon:SetTexture(buttonIcon:GetTexture())
			MegaMacro_FrameText:SetText(macro.Code)
		else
			buttonFrame:SetChecked(false)
		end
	end
end

local function SetMacroItems()
	local items = nil

	if SelectedScope == MegaMacroScopeCodes.Global then
		items = MegaMacroGlobalData.Macros
	end

	MacroItems = items or {}

	table.sort(
		MacroItems,
		function(left, right)
			return left.DisplayName < right.DisplayName
		end)

	for i=1, MegaMacroHelper.HighestMaxMacroCount do
		local buttonFrame, buttonName, buttonIcon = GetMacroButtonUI(i)

		local macro = MacroItems[i]

		if macro == nil then
			buttonFrame.Macro = nil
			buttonFrame:SetChecked(false)
			buttonFrame:Disable()
			buttonName:SetText("")
			buttonIcon:SetTexture("")
		else
			buttonFrame.Macro = macro
			buttonFrame:Enable()
			buttonName:SetText(macro.DisplayName)
			buttonIcon:SetTexture("")
		end
	end

	SelectMacro(MacroItems[1])
end

function MegaMacro_Window_OnLoad()
    -- Global, Class, ClassSpec, Character, CharacterSpec
	PanelTemplates_SetNumTabs(MegaMacro_Frame, 5)
	PanelTemplates_SetTab(MegaMacro_Frame, 1)
end

function MegaMacro_Window_OnShow()
	IsOpen = true
end

function MegaMacro_Window_OnHide()
	IsOpen = false
    MegaMacro_PopupFrame:Hide()
end

function MegaMacro_TabChanged(tabId, arg1)
	MegaMacro_ButtonScrollFrame:SetVerticalScroll(0)

	if tabId == 1 then
		SelectedScope = MegaMacroScopeCodes.Global
	elseif tabId == 2 then
		SelectedScope = MegaMacroScopeCodes.Class
	elseif tabId == 3 then
		SelectedScope = MegaMacroScopeCodes.Specialization
	elseif tabId == 4 then
		SelectedScope = MegaMacroScopeCodes.Character
	elseif tabId == 5 then
		SelectedScope = MegaMacroScopeCodes.CharacterSpecialization
	end

	InitializeMacroSlots()
	SetMacroItems()
end

function MegaMacro_ButtonContainer_OnLoad(self)
	CreateMacroSlotFrames()
end

function MegaMacro_ButtonContainer_OnShow(self)
	InitializeMacroSlots()
	SetMacroItems()
end

function MegaMacro_MacroButton_OnClick(self)
	SelectMacro(self.Macro)
end

function MegaMacro_EditButton_OnClick(self, button)
end

function MegaMacro_TextBox_TextChanged(self)
	if SelectedMacro ~= nil and SelectedMacro.Code ~= MegaMacro_FrameText:GetText() then
		MegaMacro_SaveButton:Enable()
		MegaMacro_CancelButton:Enable()
	else
		MegaMacro_SaveButton:Disable()
		MegaMacro_CancelButton:Disable()
	end

    if MegaMacro_PopupFrame.mode == "new" then
        MegaMacro_PopupFrame:Hide()
    end

    MegaMacro_FrameCharLimitText:SetFormattedText(
		rendering.CharLimitMessageFormat,
		MegaMacro_FrameText:GetNumLetters(),
		MegaMacroHelper.MaxMacroSize)

    ScrollingEdit_OnTextChanged(self, self:GetParent())
end

function MegaMacro_CancelButton_OnClick()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)

	if SelectedMacro ~= nil then
		MegaMacro_FrameText:SetText(SelectedMacro.Code)
	end

	MegaMacro_PopupFrame:Hide()
	MegaMacro_FrameText:ClearFocus()
end

function MegaMacro_SaveButton_OnClick()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	SaveMacro()
	MegaMacro_PopupFrame:Hide()
	MegaMacro_FrameText:ClearFocus()
end

function MegaMacro_NewButton_OnClick()
	MegaMacro_PopupFrame.mode = "new"
	MegaMacro_PopupFrame:Show()
end

function MegaMacro_EditOkButton_OnClick()
    -- create/update editted macro
	MegaMacro_PopupFrame:Hide()
end

function MegaMacro_EditCancelButton_OnClick()
	MegaMacro_PopupFrame:Hide()
	MegaMacro_PopupFrame.selectedIcon = nil
end