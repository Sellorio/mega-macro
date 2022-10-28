local rendering = {
	MacrosPerRow = 12,
	CharLimitMessageFormat = "%s/%s Characters Used"
}

local PopupModes = {
	New = 0,
	Edit = 1
}

local PlusTexture = 3192688--135769

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
MegaMacroWindowTogglingMode = false

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
	return _G[buttonName], _G[buttonName .. "Name"], _G[buttonName].Icon
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

local function FixIconPanelPosition()
	local button = MegaMacro_PopupButton1
	local point, relativeTo, relativePoint, x, y = button:GetPoint()
	button:SetPoint(point, relativeTo:GetName(), relativePoint, x, y - 40)
end

local function UpdateIconList()
	local searchText = MegaMacro_IconSearchBox:GetText()
	local items = MegaMacroIconNavigator.Search(searchText)
	local itemCount = #items

	IconList = { { Name = "No Icon", Icon = MegaMacroTexture } }

	for i=1, itemCount do
		IconList[i + 1] = items[i]
	end
end

local function InitializeIconListPanel()
	if not IconListInitialized then
		BuildIconArray(MegaMacro_PopupFrame, "MegaMacro_PopupButton", "MegaMacro_PopupButtonTemplate", NUM_ICONS_PER_ROW, NUM_ICON_ROWS)
		FixIconPanelPosition()
		IconListInitialized = true
	end
end

local function InitializeTabs()
	local playerName = UnitName("player")
	MegaMacro_FrameTab2:SetText(MegaMacroCachedClass)
	MegaMacro_FrameTab4:SetText(playerName)

	if MegaMacroCachedSpecialization == '' then
		MegaMacro_FrameTab3:SetText("Locked")
		MegaMacro_FrameTab5:SetText("Locked")
		MegaMacro_FrameTab3:Disable()
		MegaMacro_FrameTab5:Disable()
	else
		MegaMacro_FrameTab3:SetText(MegaMacroCachedSpecialization)
		MegaMacro_FrameTab5:SetText(playerName.." "..MegaMacroCachedSpecialization)
		MegaMacro_FrameTab3:Enable()
		MegaMacro_FrameTab5:Enable()
	end
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
	MegaMacro_CancelButton:Disable()
end

local function RefreshSelectedMacroIcon()
	local displayedTexture = ""

	if SelectedMacro then
		if SelectedIcon == MegaMacroTexture then
			local data = MegaMacroIconEvaluator.GetCachedData(SelectedMacro.Id)
			displayedTexture = data and data.Icon or MegaMacroTexture
		else
			local isStaticTextureFallback = MegaMacro_FallbackTextureCheckBox:GetChecked()
			displayedTexture = select(4, MegaMacroIconEvaluator.ComputeMacroIcon(SelectedMacro, SelectedIcon, isStaticTextureFallback))
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

	local newMacroButtonCreated = false

	for i=1, HighestMaxMacroCount do
		local buttonFrame, buttonName, buttonIcon = GetMacroButtonUI(i)

		local macro = MacroItems[i]

		if macro then
			buttonFrame.Macro = macro
			buttonFrame.IsNewButton = false
			-- buttonFrame:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
			buttonName:SetText(macro.DisplayName)
			local data = MegaMacroIconEvaluator.GetCachedData(macro.Id)
			buttonIcon:SetTexture(data and data.Icon)
			buttonIcon:SetDesaturated(false)
			buttonIcon:SetTexCoord(0, 1, 0, 1)
			buttonIcon:SetAlpha(1)
		elseif not newMacroButtonCreated then
			buttonFrame.Macro = nil
			buttonFrame.IsNewButton = true
			-- buttonFrame:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
			buttonName:SetText("")
			buttonIcon:SetTexture(PlusTexture)
			buttonIcon:SetDesaturated(true)
			buttonIcon:SetTexCoord(.08, .92, .08, .92)
			buttonIcon:SetAlpha(0.5)
			newMacroButtonCreated = true
		else
			buttonFrame.Macro = nil
			buttonFrame.IsNewButton = false
			-- buttonFrame:SetHighlightTexture(nil)
			buttonName:SetText("")
			buttonIcon:SetTexture("")
			buttonIcon:SetDesaturated(false)
			buttonIcon:SetTexCoord(0, 1, 0, 1)
			buttonIcon:SetAlpha(1)
		end
	end

	SelectMacro(MacroItems[1])
end

local function NewMacro()
	SelectMacro(nil)

	local button = _G["MegaMacro_MacroButton"..(#MacroItems + 1)]

	if button then
		button:SetChecked(true)
	end

	PopupMode = PopupModes.New
	MegaMacro_PopupEditBox:SetText("")
	MegaMacro_FallbackTextureCheckBox:SetChecked(true)
	MegaMacro_IconSearchBox:SetText("")
	MegaMacro_PopupFrame:Show()
end

local function DeleteMegaMacro()
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

	if type == "macro" then
		local macroId = MegaMacroEngine.GetMacroIdFromIndex(macroIndex)

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
		else
			ClearCursor()
			local name, _, body = GetMacroInfo(macroIndex)
			local newMacro = MegaMacro.Create(name, targetScope, MegaMacroTexture)

			if newMacro then
				MegaMacro.UpdateCode(newMacro, body)
			end

			SetMacroItems()
			SelectMacro(newMacro)

			if not InCombatLockdown() then
				local newMacroIndex = MegaMacroEngine.GetMacroIndexFromId(newMacro.Id)
				if newMacroIndex then
					for i=1, 120 do
						local actionButtonType, actionButtonArg = GetActionInfo(i)
						if actionButtonType == "macro" and actionButtonArg == macroIndex then
							PickupMacro(newMacroIndex)
							PlaceAction(i)
							ClearCursor()
						end
					end
				end

				DeleteMacro(macroIndex)

				if MacroFrame:IsVisible() then
					MacroFrame_Update()
					if MacroFrame.selectedTab == 1 then
						MacroFrame_SetAccountMacros()
					else
						MacroFrame_SetCharacterMacros()
					end
				end
			end
		end
	end

	return type ~= nil
end

local function UpdateSearchPlaceholder()
	if MegaMacro_IconSearchBox:GetText() == "" then
		MegaMacro_IconSearchPlaceholder:SetAlpha(0.4)
	else
		MegaMacro_IconSearchPlaceholder:SetAlpha(0.0)
	end
end

StaticPopupDialogs["CONFIRM_DELETE_SELECTED_MEGA_MACRO"] = {
	text = CONFIRM_DELETE_MACRO,
	button1 = OKAY,
	button2 = CANCEL,
	OnAccept = DeleteMegaMacro,
	timeout = 0,
	whileDead = 1,
	showAlert = 1
}

MegaMacroWindow = {
	Show = function()
		if MegaMacroConfig_IsWindowDialog() then
			MegaMacro_Frame:SetMovable(false)
			MegaMacro_ToggleWindowModeButton:SetText("Unlock")
			ShowUIPanel(MegaMacro_Frame);
		else
			local relativePoint, x, y = MegaMacroConfig_GetWindowPosition()
			MegaMacro_Frame:SetMovable(true)
			MegaMacro_Frame:SetSize(640, 524)
			MegaMacro_Frame:ClearAllPoints()
			MegaMacro_Frame:SetPoint(relativePoint, x, y)
			MegaMacro_ToggleWindowModeButton:SetText("Lock")
			MegaMacro_Frame:Show()
		end
	end,
	IsOpen = function()
		return IsOpen
	end,
	SaveMacro = function()
		SaveMacro()
	end,
	OnSpecializationChanged = function(oldValue, newValue)
		InitializeTabs()
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
	InitializeTabs()
	InitializeIconListPanel()
	UpdateSearchPlaceholder()
	MegaMacro_FallbackTextureDescription:SetAlpha(0.6)
end

function MegaMacro_Window_OnHide()
	SaveMacro()
	IsOpen = false
    MegaMacro_PopupFrame:Hide()
end

function MegaMacro_Window_OnDragStop()
	local _, _, relativePoint, xOfs, yOfs = MegaMacro_Frame:GetPoint()
	MegaMacroGlobalData.WindowInfo.RelativePoint = relativePoint
	MegaMacroGlobalData.WindowInfo.X = xOfs
	MegaMacroGlobalData.WindowInfo.Y = yOfs
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
		InitializeTabs()
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
	if not HandleReceiveDrag(SelectedScope) then
		if self.Macro then
			SelectMacro(self.Macro)
		elseif self.IsNewButton then
			NewMacro()
		else
			self:SetChecked(false)
		end
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

function MegaMacro_TextBox_OnKeyDown(_, key)
	if SelectedMacro then
		if key == "S" and IsControlKeyDown() then
			MegaMacro_SaveButton_OnClick()
			MegaMacro_FrameText:SetFocus()
		end
	end
end

function MegaMacro_TextBox_TextChanged(self)
	local text = MegaMacro_FrameText:GetText()
	if SelectedMacro ~= nil and SelectedMacro.Code ~= text then
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
	ScrollingEdit_OnTextChanged(MegaMacro_FormattedFrameText, MegaMacro_FormattedFrameText:GetParent())
	MegaMacro_FormattedFrameText:SetText(MegaMacroParser.Parse(text))
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
		MegaMacro_FallbackTextureCheckBox:SetChecked(SelectedMacro.IsStaticTextureFallback)
		MegaMacro_IconSearchBox:SetText("")
		MegaMacro_PopupFrame:Show()
		PopupMode = PopupModes.Edit
	end
end

function MegaMacro_EditOkButton_OnClick()
	local enteredText = MegaMacro_PopupEditBox:GetText()
	local isStaticTextureFallback = MegaMacro_FallbackTextureCheckBox:GetChecked()

	if PopupMode == PopupModes.Edit and SelectedMacro ~= nil then
		local selectedMacro = SelectedMacro
		MegaMacro.UpdateDetails(SelectedMacro, enteredText, SelectedIcon, isStaticTextureFallback)
		SetMacroItems()
		SelectMacro(selectedMacro)
	elseif PopupMode == PopupModes.New then
		local createdMacro = MegaMacro.Create(enteredText, SelectedScope, SelectedIcon, isStaticTextureFallback)
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
		local iconListData = IconList[index]

		if index <= numMacroIcons and iconListData then
			macroPopupIcon:SetTexture(iconListData.Icon);
			macroPopupButton.SpellId = iconListData.SpellId
			macroPopupButton:Show();
		else
			macroPopupIcon:SetTexture("");
			macroPopupButton.SpellId = nil
			macroPopupButton:Hide();
		end

		macroPopupButton:SetChecked(iconListData and SelectedIcon == iconListData.Icon)
	end

	-- Scrollbar stuff
	FauxScrollFrame_Update(MegaMacro_PopupScrollFrame, ceil(numMacroIcons / NUM_ICONS_PER_ROW) + 1, NUM_ICON_ROWS, MACRO_ICON_ROW_HEIGHT );
end

function MegaMacro_PopupButton_OnClick(self)
	local buttonIcon = _G[self:GetName().."Icon"]
	SelectIcon(buttonIcon:GetTexture())
end

function MegaMacro_PopupButton_OnEnter(self)
	if self.SpellId then
		GameTooltip:Hide()
		GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
		GameTooltip:SetSpellByID(self.SpellId)
		GameTooltip:Show()
	end
end

function MegaMacro_PopupButton_OnLeave(self)
	GameTooltip:Hide()
end

function MegaMacro_ToggleWindowModeButton_OnClick()
	if MegaMacroConfig_IsWindowDialog() then
		local _, _, relativePoint, xOfs, yOfs = MegaMacro_Frame:GetPoint()
		MegaMacroGlobalData.WindowInfo = {
			IsDialog = false,
			RelativePoint = relativePoint,
			X = xOfs,
			Y = yOfs
		}
	else
		MegaMacroGlobalData.WindowInfo = nil
	end

	MegaMacroWindowTogglingMode = true
	HideUIPanel(MegaMacro_Frame)
	MegaMacroWindow.Show()
	MegaMacroWindowTogglingMode = false
end

function MegaMacro_FallbackTextureCheckBox_OnClick()
	RefreshSelectedMacroIcon()
end

function MegaMacro_IconSearchBox_TextChanged()
	UpdateSearchPlaceholder()
	UpdateIconList()
end

function MegaMacro_RegisterShiftClicks()
	function shiftClickHookFunction(self) 
		local slot = SpellBook_GetSpellBookSlot(self);
		if ( slot > MAX_SPELLS ) then
			return
		end
	
		if IsModifiedClick("CHATLINK") and MegaMacro_FrameText:HasFocus() then
			local spellName, subSpellName = GetSpellBookItemName(slot, SpellBookFrame.bookType)
	
			if spellName and not IsPassiveSpell(slot, SpellBookFrame.bookType) then
				if subSpellName and string.len(subSpellName) > 0 then
					MegaMacro_FrameText:Insert(spellName.."("..subSpellName..")")
				else
					MegaMacro_FrameText:Insert(spellName)
				end
			end
		end
	end
	
	-- This is a kind of a hack, but it gets the shift click to work. We loop through all the spellbook buttons and hook their OnClick functions individually, since the generic SpellButton_OnModifiedClick was removed.
	for i = 1, 120 do
		local buttonName = "SpellButton" .. i
		if _G[buttonName] ~= nil then
			hooksecurefunc(_G[buttonName], "OnModifiedClick", shiftClickHookFunction)
		end
	end
end

