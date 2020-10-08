local rendering = {
	MacrosPerRow = 12,
	CharLimitMessageFormat = "%s/%s Characters Used"
}

local PopupModes = {
	New = 0,
	Edit = 1
}

local IsOpen = false
local SelectedScope = MegaMacroScopes.Global
local MacroItems = {}
local SelectedMacro = nil
local PopupMode = nil
local IconListInitialized = false
local SelectedIcon = nil
local IconList = {}

NUM_ICONS_PER_ROW = 10
NUM_ICON_ROWS = 9
NUM_MACRO_ICONS_SHOWN = NUM_ICONS_PER_ROW * NUM_ICON_ROWS
MACRO_ICON_ROW_HEIGHT = 36

UIPanelWindows["MegaMacro_Frame"] = { area = "left", pushable = 1, whileDead = 1, width = PANEL_DEFAULT_WIDTH + 302 }

local function GetScopeFromTabIndex(tabIndex)
	if tabIndex == 1 then
		return MegaMacroScopes.Global
	elseif tabIndex == 2 then
		return MegaMacroScopes.Class
	elseif tabIndex == 3 then
		return MegaMacroScopes.Specialization
	elseif tabIndex == 4 then
		return MegaMacroScopes.Character
	elseif tabIndex == 5 then
		return MegaMacroScopes.CharacterSpecialization
	end
end

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

local function LoadIcons()
	-- We need to avoid adding duplicate spellIDs from the spellbook tabs for your other specs.
	local activeIcons = {};

	for i = 1, GetNumSpellTabs() do
		local tab, tabTex, offset, numSpells, _ = GetSpellTabInfo(i);
		offset = offset + 1;
		local tabEnd = offset + numSpells;
		for j = offset, tabEnd - 1 do
			--to get spell info by slot, you have to pass in a pet argument
			local spellType, ID = GetSpellBookItemInfo(j, "player"); 
			if (spellType ~= "FUTURESPELL") then
				local fileID = GetSpellBookItemTexture(j, "player");
				if (fileID) then
					activeIcons[fileID] = true;
				end
			end
			if (spellType == "FLYOUT") then
				local _, _, numSlots, isKnown = GetFlyoutInfo(ID);
				if (isKnown and numSlots > 0) then
					for k = 1, numSlots do 
						local spellID, overrideSpellID, isKnown = GetFlyoutSlotInfo(ID, k)
						if (isKnown) then
							local fileID = GetSpellTexture(spellID);
							if (fileID) then
								activeIcons[fileID] = true;
							end
						end
					end
				end
			end
		end
	end

	IconList = { MegaMacroTexture };
	for fileDataID in pairs(activeIcons) do
		IconList[#IconList + 1] = fileDataID;
	end

	GetLooseMacroIcons(IconList);
	GetLooseMacroItemIcons(IconList);
	GetMacroIcons(IconList);
	GetMacroItemIcons(IconList);

	local iconListLength = #IconList
	for i=1, iconListLength do
		if type(IconList[i]) ~= "number" then
			IconList[i] = "INTERFACE\\ICONS\\"..IconList[i]
		end
	end
end

local function InitializeIconListPanel()
	if not IconListInitialized then
		BuildIconArray(MegaMacro_PopupFrame, "MegaMacro_PopupButton", "MegaMacro_PopupButtonTemplate", NUM_ICONS_PER_ROW, NUM_ICON_ROWS)
		LoadIcons()
		IconListInitialized = true
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

local function RefreshSelectedMacroIcon()
	local displayedTexture = ""

	if SelectedMacro then
		if SelectedIcon == MegaMacroTexture then
			displayedTexture = MegaMacroIconEvaluator.GetTextureFromCache(SelectedMacro.Id) or MegaMacroTexture
		else
			displayedTexture = SelectedIcon
		end
	end

	MegaMacro_FrameSelectedMacroButtonIcon:SetTexture(displayedTexture)
end

local function SelectIcon(texture)
	SelectedIcon = texture or MegaMacroTexture
	RefreshSelectedMacroIcon()

	local i = 1
	while true do
		local iconButton = _G["MegaMacro_PopupButton"..i]
		local iconButtonIcon = _G["MegaMacro_PopupButton"..i.."Icon"]

		if not iconButton then
			break
		end

		iconButton:SetChecked(SelectedIcon == iconButtonIcon:GetTexture())
		i = i + 1
	end
end

local function SelectMacro(macro)
	SaveMacro()
	SelectedMacro = nil
	MegaMacro_PopupFrame:Hide()
	MegaMacro_FrameSelectedMacroName:SetText("")
	MegaMacro_FrameSelectedMacroButtonIcon:SetTexture("")
	MegaMacro_FrameText:SetText("")
	MegaMacro_EditButton:Disable();
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
			MegaMacro_EditButton:Enable();
			MegaMacro_DeleteButton:Enable();
			MegaMacro_FrameText:Enable()
		else
			buttonFrame:SetChecked(false)
		end
	end

	SelectIcon(macro and macro.StaticTexture)
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
			buttonName:SetText("")
			buttonIcon:SetTexture("")
		else
			buttonFrame.Macro = macro
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
					ShowToolTipForMegaMacro(macro.Id)
				end
			elseif focusFrame == "MegaMacro_FrameSelectedMacroButton" and SelectedMacro and SelectedMacro.Id == updatedMacroId then
				ShowToolTipForMegaMacro(SelectedMacro.Id)
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

local function HandleReceiveDrag(targetScope)
	local type, macroIndex = GetCursorInfo()
	local macroId = type == "macro" and MegaMacroEngine.GetMacroIdFromIndex(macroIndex)

	if macroId then
		local macro = MegaMacro.GetById(macroId)
		ClearCursor()

		if IsControlKeyDown() then
			local newDisplayName = macro.Scope == targetScope and macro.DisplayName.." copy" or macro.DisplayName
			local newMacro = MegaMacro.Create(newDisplayName, targetScope, macro.StaticTexture)
			MegaMacro.UpdateCode(newMacro, macro.Code)

			if targetScope == SelectedScope then
				SetMacroItems()
				SelectMacro(newMacro)
			end
		elseif targetScope == macro.Scope then
			-- do nothing
		else
			local newMacro = MegaMacro.Move(macro, targetScope)

			if targetScope == SelectedScope then
				SetMacroItems()
				SelectMacro(newMacro)
			elseif macro.Scope == SelectedScope then
				SetMacroItems()
			end
		end
	end

	return type ~= nil
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
			RefreshSelectedMacroIcon()
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
	InitializeIconListPanel()
end

function MegaMacro_Window_OnHide()
	SaveMacro()
	IsOpen = false
    MegaMacro_PopupFrame:Hide()
end

function MegaMacro_FrameTab_OnClick(self)
	local tabIndex = self:GetID()
	local scope = GetScopeFromTabIndex(tabIndex)

	if not HandleReceiveDrag(scope) then
		PanelTemplates_SetTab(MegaMacro_Frame, tabIndex);
		MegaMacro_ButtonScrollFrame:SetVerticalScroll(0)

		SelectedScope = scope

		InitializeMacroSlots()
		SetMacroItems()
	end
end

function MegaMacro_FrameTab_OnReceiveDrag(self)
	local tabIndex = self:GetID()
	local scope = GetScopeFromTabIndex(tabIndex)
	HandleReceiveDrag(scope)
end

function MegaMacro_ButtonContainer_OnLoad()
	CreateMacroSlotFrames()
end

function MegaMacro_ButtonContainer_OnShow()
	InitializeMacroSlots()
	SetMacroItems()
end

function MegaMacro_ButtonContainer_OnReceiveDrag()
	HandleReceiveDrag(SelectedScope)
end

function MegaMacro_MacroButton_OnClick(self)
	if not self.Macro then
		self:SetChecked(false)
	end

	if not HandleReceiveDrag(SelectedScope) and self.Macro then
		SelectMacro(self.Macro)
	end
end

function MegaMacro_MacroButton_OnEnter(self)
	if self.Macro then
		ShowToolTipForMegaMacro(self.Macro.Id)
	end
end

function MegaMacro_MacroButton_OnLeave(self)
	GameTooltip:Hide()
end

function MegaMacro_MacroButton_OnDragStart(self)
	if self.Macro then
		PickupMegaMacro(self.Macro)
	end
end

function MegaMacro_MacroButton_OnReceiveDrag(self)
	HandleReceiveDrag(SelectedScope)
end

function MegaMacro_FrameSelectedMacroButton_OnEnter()
	if SelectedMacro then
		ShowToolTipForMegaMacro(SelectedMacro.Id)
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

function MegaMacro_EditButton_OnClick()
	if SelectedMacro ~= nil then
		MegaMacro_PopupEditBox:SetText(SelectedMacro.DisplayName)
		MegaMacro_PopupFrame:Show()
		PopupMode = PopupModes.Edit
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

	if PopupMode == PopupModes.Edit and SelectedMacro ~= nil then
		local selectedMacro = SelectedMacro
		MegaMacro.UpdateDetails(SelectedMacro, enteredText, SelectedIcon)
		SetMacroItems()
		SelectMacro(selectedMacro)
	elseif PopupMode == PopupModes.New then
		local createdMacro = MegaMacro.Create(enteredText, SelectedScope, SelectedIcon)
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
	if SelectedMacro then
		SelectIcon(SelectedMacro.StaticTexture)
	else
		SelectMacro(MacroItems[1])
	end

	MegaMacro_PopupFrame:Hide()
end

function MegaMacro_EditCancelButton_OnClick_Wrapper()
	MegaMacro_EditCancelButton_OnClick()
end

function MegaMacro_PopupFrame_OnUpdate()
	local numMacroIcons = #IconList;
	local macroPopupIcon, macroPopupButton;
	local macroPopupOffset = FauxScrollFrame_GetOffset(MegaMacro_PopupScrollFrame);
	local index;

	-- Icon list
	for i=1, NUM_MACRO_ICONS_SHOWN do
		macroPopupButton = _G["MegaMacro_PopupButton"..i];
		macroPopupIcon = _G["MegaMacro_PopupButton"..i.."Icon"];
		index = (macroPopupOffset * NUM_ICONS_PER_ROW) + i;
		local texture = IconList[i]

		if index <= numMacroIcons and texture then
			macroPopupIcon:SetTexture(texture);
			macroPopupButton:Show();
		else
			macroPopupIcon:SetTexture("");
			macroPopupButton:Hide();
		end

		macroPopupButton:SetChecked(SelectedIcon == texture)
	end

	-- Scrollbar stuff
	FauxScrollFrame_Update(MegaMacro_PopupScrollFrame, ceil(numMacroIcons / NUM_ICONS_PER_ROW) + 1, NUM_ICON_ROWS, MACRO_ICON_ROW_HEIGHT );
end

function MegaMacro_PopupButton_OnClick(self)
	local buttonIcon = _G[self:GetName().."Icon"]
	SelectIcon(buttonIcon:GetTexture())
end