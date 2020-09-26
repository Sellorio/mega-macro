local rendering = {
	MacrosPerRow = 12,
	CharLimitMessageFormat = "%s/%s Characters Used"
}

local PopupModes = {
	New = 0,
	Rename = 1
}

local IsOpen = false
local SelectedScope = MegaMacroScopes.Global
local MacroItems = {}
local SelectedMacro = nil
local PopupMode = nil

NUM_ICONS_PER_ROW = 10
NUM_ICON_ROWS = 9
NUM_MACRO_ICONS_SHOWN = NUM_ICONS_PER_ROW * NUM_ICON_ROWS
MACRO_ICON_ROW_HEIGHT = 36

UIPanelWindows["MegaMacro_Frame"] = { area = "left", pushable = 1, whileDead = 1, width = PANEL_DEFAULT_WIDTH + 302 }

local function GetMacroButtonUI(index)
	local buttonName = "MegaMacro_MacroButton" .. index
	return _G[buttonName], _G[buttonName .. "Name"], _G[buttonName .. "Icon"]
end

-- Creates the button frames for the macro slots
local function CreateMacroSlotFrames()
	for i=1, HighestMaxMacroCount do
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

local function InitializeTabTitles()
	local playerName = UnitName("player")
	MegaMacro_FrameTab2:SetText(MegaMacroCachedClass);
	MegaMacro_FrameTab3:SetText(MegaMacroCachedSpecialization);
	MegaMacro_FrameTab4:SetText(playerName);
	MegaMacro_FrameTab5:SetText(playerName.." "..MegaMacroCachedSpecialization);
end

-- Shows and hides macro slot buttons based on the number of slots available in the scope
local function InitializeMacroSlots()
	local scopeSlotCount = MegaMacro.GetSlotCount(SelectedScope)

	for i=1, scopeSlotCount do
		local buttonFrame = _G["MegaMacro_MacroButton" .. i]

		if buttonFrame == nil then
			break
		end

		buttonFrame:Show()
	end

	for i=scopeSlotCount+1, HighestMaxMacroCount do
		local buttonFrame = _G["MegaMacro_MacroButton" .. i]

		if buttonFrame == nil then
			break
		end

		buttonFrame:Hide()
	end
end

local function SaveMacro()
	local newCode = MegaMacro_FrameText:GetText()
	if SelectedMacro ~= nil and SelectedMacro.Code ~= newCode then
		MegaMacro.UpdateCode(SelectedMacro, newCode)
	end

	MegaMacro_SaveButton:Disable()
end

local function SelectMacro(macro)
	SaveMacro()
	SelectedMacro = nil
	MegaMacro_PopupFrame:Hide()
	MegaMacro_FrameSelectedMacroName:SetText("")
	MegaMacro_FrameSelectedMacroButtonIcon:SetTexture("")
	MegaMacro_FrameText:SetText("")
	MegaMacro_RenameButton:Disable();
	MegaMacro_DeleteButton:Disable();
	MegaMacro_SaveButton:Disable()
	MegaMacro_CancelButton:Disable()
	MegaMacro_FrameText:Disable()

	for i=1, HighestMaxMacroCount do
		local buttonFrame, _, buttonIcon = GetMacroButtonUI(i)

		if macro and buttonFrame.Macro == macro then
			buttonFrame:SetChecked(true)
			SelectedMacro = macro
			MegaMacro_FrameSelectedMacroName:SetText(macro.DisplayName)
			MegaMacro_FrameSelectedMacroButtonIcon:SetTexture(buttonIcon:GetTexture())
			MegaMacro_FrameText:SetText(macro.Code)
			MegaMacro_RenameButton:Enable();
			MegaMacro_DeleteButton:Enable();
			MegaMacro_FrameText:Enable()
		else
			buttonFrame:SetChecked(false)
		end
	end

end

local function SetMacroItems()
	local items = MegaMacro.GetMacrosInScope(SelectedScope)
	MacroItems = items or {}

	table.sort(
		MacroItems,
		function(left, right)
			return left.DisplayName < right.DisplayName
		end)

	for i=1, HighestMaxMacroCount do
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
			buttonIcon:SetTexture(MegaMacroIconEvaluator.GetTextureFromCache(macro.Id))
		end
	end

	SelectMacro(MacroItems[1])
end

local function DeleteMacro()
	if SelectedMacro ~= nil then
		MegaMacro.Delete(SelectedMacro)
		SetMacroItems()
	end
end

local function UpdateTooltipIfButtonIsHovered(updatedMacroId)
	local mouseFocus = GetMouseFocus()

	if mouseFocus then
		local focusFrame = mouseFocus:GetName()

		if focusFrame then
			if string.find(focusFrame, "^MegaMacro_MacroButton%d+$") then
				local macro = _G[focusFrame].Macro

				if macro and macro.Id == updatedMacroId then
					ShowToolTipForMegaMacro(macro)
				end
			elseif focusFrame == "MegaMacro_FrameSelectedMacroButton" and SelectedMacro and SelectedMacro.Id == updatedMacroId then
				ShowToolTipForMegaMacro(SelectedMacro)
			end
		end
	end
end

local function PickupMegaMacro(macro)
	local macroIndex = MegaMacroEngine.GetMacroIndexFromId(macro.Id)

	if macroIndex then
		PickupMacro(macroIndex)
	end
end

StaticPopupDialogs["CONFIRM_DELETE_SELECTED_MEGA_MACRO"] = {
	text = CONFIRM_DELETE_MACRO,
	button1 = OKAY,
	button2 = CANCEL,
	OnAccept = DeleteMacro,
	timeout = 0,
	whileDead = 1,
	showAlert = 1
}

MegaMacroWindow = {
    Show = function()
        ShowUIPanel(MegaMacro_Frame);
	end,
	IsOpen = function()
		return IsOpen
	end,
	SaveMacro = function()
		SaveMacro()
	end,
	OnSpecializationChanged = function(oldValue, newValue)
		InitializeTabTitles()
		SetMacroItems()
	end
}

function MegaMacro_OnIconUpdated(macroId, texture)
	if IsOpen then
		if SelectedMacro and SelectedMacro.Id == macroId then
			MegaMacro_FrameSelectedMacroButtonIcon:SetTexture(texture)
		end

		local macroItemsLength = #MacroItems

		for i=1, macroItemsLength do
			if MacroItems[i].Id == macroId then
				local _, _, buttonIcon = GetMacroButtonUI(i)
				buttonIcon:SetTexture(texture)
			end
		end

		UpdateTooltipIfButtonIsHovered(macroId)
	end
end

function MegaMacro_Window_OnLoad()
    -- Global, Class, ClassSpec, Character, CharacterSpec
	PanelTemplates_SetNumTabs(MegaMacro_Frame, 5)
	PanelTemplates_SetTab(MegaMacro_Frame, 1)
	MegaMacroIconEvaluator.OnIconUpdated(function(macroId, texture)
		MegaMacro_OnIconUpdated(macroId, texture)
	end)
end

function MegaMacro_Window_OnShow()
	IsOpen = true
	InitializeTabTitles()
end

function MegaMacro_Window_OnHide()
	SaveMacro()
	IsOpen = false
    MegaMacro_PopupFrame:Hide()
end

function MegaMacro_TabChanged(tabId)
	MegaMacro_ButtonScrollFrame:SetVerticalScroll(0)

	if tabId == 1 then
		SelectedScope = MegaMacroScopes.Global
	elseif tabId == 2 then
		SelectedScope = MegaMacroScopes.Class
	elseif tabId == 3 then
		SelectedScope = MegaMacroScopes.Specialization
	elseif tabId == 4 then
		SelectedScope = MegaMacroScopes.Character
	elseif tabId == 5 then
		SelectedScope = MegaMacroScopes.CharacterSpecialization
	end

	InitializeMacroSlots()
	SetMacroItems()
end

function MegaMacro_ButtonContainer_OnLoad()
	CreateMacroSlotFrames()
end

function MegaMacro_ButtonContainer_OnShow()
	InitializeMacroSlots()
	SetMacroItems()
end

function MegaMacro_MacroButton_OnClick(self)
	SelectMacro(self.Macro)
end

function MegaMacro_MacroButton_OnEnter(self)
	if self.Macro then
		ShowToolTipForMegaMacro(self.Macro)
	end
end

function MegaMacro_MacroButton_OnLeave()
	GameTooltip:Hide()
end

function MegaMacro_MacroButton_OnDragStart(self)
	if self.Macro then
		PickupMegaMacro(self.Macro)
	end
end

function MegaMacro_FrameSelectedMacroButton_OnEnter()
	if SelectedMacro then
		ShowToolTipForMegaMacro(SelectedMacro)
	end
end

function MegaMacro_FrameSelectedMacroButton_OnLeave()
	GameTooltip:Hide()
end

function MegaMacro_FrameSelectedMacroButton_OnDragStart()
	if SelectedMacro then
		PickupMegaMacro(SelectedMacro)
	end
end

function MegaMacro_FrameTextButton_OnClick()
	if SelectedMacro then
		MegaMacro_FrameText:SetFocus();
	end
end

function MegaMacro_TextBox_TextChanged(self)
	if SelectedMacro ~= nil and SelectedMacro.Code ~= MegaMacro_FrameText:GetText() then
		MegaMacro_SaveButton:Enable()
		MegaMacro_CancelButton:Enable()
	else
		MegaMacro_SaveButton:Disable()
		MegaMacro_CancelButton:Disable()
	end

    MegaMacro_FrameCharLimitText:SetFormattedText(
		rendering.CharLimitMessageFormat,
		MegaMacro_FrameText:GetNumLetters(),
		MegaMacroCodeMaxLength)

    ScrollingEdit_OnTextChanged(self, self:GetParent())
end

function MegaMacro_CancelButton_OnClick()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)

	if SelectedMacro ~= nil then
		MegaMacro_FrameText:SetText(SelectedMacro.Code)
	end

	MegaMacro_PopupFrame:Hide()
	MegaMacro_FrameText:ClearFocus()
	MegaMacro_CancelButton:Disable()
end

function MegaMacro_SaveButton_OnClick()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	SaveMacro()
	MegaMacro_PopupFrame:Hide()
	MegaMacro_FrameText:ClearFocus()
end

function MegaMacro_RenameButton_OnClick()
	if SelectedMacro ~= nil then
		MegaMacro_PopupEditBox:SetText(SelectedMacro.DisplayName)
		MegaMacro_PopupFrame:Show()
		PopupMode = PopupModes.Rename
	end
end

function MegaMacro_NewButton_OnClick()
	SelectMacro(nil)
	PopupMode = PopupModes.New
	MegaMacro_PopupFrame:Show()
	MegaMacro_PopupEditBox:SetText("")
end

function MegaMacro_EditOkButton_OnClick()
	local enteredText = MegaMacro_PopupEditBox:GetText()

	if PopupMode == PopupModes.Rename and SelectedMacro ~= nil then
		local selectedMacro = SelectedMacro
		MegaMacro.Rename(SelectedMacro, enteredText)
		SetMacroItems()
		SelectMacro(selectedMacro)
	elseif PopupMode == PopupModes.New then
		local createdMacro = MegaMacro.Create(enteredText, SelectedScope)
		SetMacroItems()
		SelectMacro(createdMacro)
		MegaMacro_FrameText:SetFocus()
	end

	MegaMacro_PopupFrame:Hide()
end

function MegaMacro_EditOkButton_OnClick_Wrapper()
	MegaMacro_EditOkButton_OnClick()
end

function MegaMacro_EditCancelButton_OnClick()
	MegaMacro_PopupFrame:Hide()
end

function MegaMacro_EditCancelButton_OnClick_Wrapper()
	MegaMacro_EditCancelButton_OnClick()
end