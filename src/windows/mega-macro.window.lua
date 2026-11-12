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
local SelectedTabIndex = 1
local CreatedSlotCount = 0

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
		return MegaMacroScopes.Inactive
	end
end

local function GetMacroButtonUI(index)
	local buttonName = "MegaMacro_MacroButton" .. index
	return _G[buttonName], _G[buttonName].Name, _G[buttonName].Icon
end

-- Creates the button frames for the macro slots
local function CreateMacroSlotFrames(count)
	for i=CreatedSlotCount+1, count do
		local button = CreateFrame("CheckButton", "MegaMacro_MacroButton" .. i, MegaMacro_ButtonContainer, "MegaMacro_ButtonTemplate")
		button:SetID(i)
		if i == 1 then
			button:SetPoint("TOPLEFT", MegaMacro_ButtonContainer, "TOPLEFT", 6, -6)
		elseif mod(i, rendering.MacrosPerRow) == 1 then
			button:SetPoint("TOP", "MegaMacro_MacroButton"..(i-rendering.MacrosPerRow), "BOTTOM", 0, -10)
		else
			button:SetPoint("LEFT", "MegaMacro_MacroButton"..(i-1), "RIGHT", 13, 0)
		end
		CreatedSlotCount = i
	end
end

-- BuildIconArray no longer exists in the game's UI code
local function CreateIconButtons()
	local firstInRow
	local previous

	for i=1, NUM_MACRO_ICONS_SHOWN do
		local button = CreateFrame("CheckButton", "MegaMacro_PopupButton"..i, MegaMacro_PopupFrame, "MegaMacro_PopupButtonTemplate")
		button:SetID(i)

		if i == 1 then
			button:SetPoint("TOPLEFT", 26, -125)
			firstInRow = button
		elseif i % NUM_ICONS_PER_ROW == 1 then
			button:SetPoint("TOPLEFT", firstInRow, "BOTTOMLEFT", 0, -8)
			firstInRow = button
		else
			button:SetPoint("LEFT", previous, "RIGHT", 10, 0)
		end

		previous = button
	end
end

local function InitializeIconListPanel()
	if not IconListInitialized then
		CreateIconButtons()
		IconListInitialized = true
	end
end

local function InitializeTabs()
	local playerName = UnitName("player")
	MegaMacro_FrameTab2:SetText(MegaMacroCachedClass)
	MegaMacro_FrameTab4:SetText(playerName)
	MegaMacro_FrameTab5:SetText("Inactive")
	MegaMacro_FrameTab6:SetText("Config")

	if MegaMacroCachedSpecialization == '' then
		MegaMacro_FrameTab3:SetText("Locked")
		MegaMacro_FrameTab3:Disable()
	else
		MegaMacro_FrameTab3:SetText(MegaMacroCachedSpecialization)
		MegaMacro_FrameTab3:Enable()
	end
end

-- Shows and hides macro slot buttons based on the number of slots available in the scope
local function InitializeMacroSlots()
	local scopeSlotCount = MegaMacro.GetSlotCount(SelectedScope)

	-- The Inactive tab only needs as many as it has macros to list
	if SelectedScope == MegaMacroScopes.Inactive then
		scopeSlotCount = math.max(HighestMaxMacroCount, #MacroItems)
	end

	for i=1, scopeSlotCount do
		local buttonFrame = _G["MegaMacro_MacroButton" .. i]

		if buttonFrame == nil then
			break
		end

		buttonFrame:Show()
	end

	for i=scopeSlotCount+1, CreatedSlotCount do
		local buttonFrame = _G["MegaMacro_MacroButton" .. i]

		if buttonFrame == nil then
			break
		end

		buttonFrame:Hide()
	end
end

local function SaveMacro()
	local newCode = MegaMacro_FrameText:GetText()
	if SelectedMacro ~= nil and not SelectedMacro.IsUnmanaged and SelectedMacro.Code ~= newCode then
		MegaMacro.UpdateCode(SelectedMacro, newCode)
	end

	MegaMacro_SaveButton:Disable()
	MegaMacro_CancelButton:Disable()
end

local function RefreshSelectedMacroIcon()
	local displayedTexture = ""

	if SelectedMacro and SelectedMacro.IsUnmanaged then
		displayedTexture = SelectedMacro.StaticTexture
	elseif SelectedMacro then
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

	for i=1, CreatedSlotCount do
		local buttonFrame, _, buttonIcon = GetMacroButtonUI(i)

		if macro and buttonFrame.Macro == macro then
			buttonFrame:SetChecked(true)
			SelectedMacro = macro
			MegaMacro_FrameSelectedMacroName:SetText(macro.DisplayName)
			MegaMacro_FrameSelectedMacroButtonIcon:SetTexture(buttonIcon:GetTexture())
			MegaMacro_FrameText:SetText(macro.Code)
			MegaMacro_DeleteButton:Enable();
			if not macro.IsUnmanaged then
				MegaMacro_EditButton:Enable();
				MegaMacro_FrameText:Enable()
			end
		else
			buttonFrame:SetChecked(false)
		end
	end

	SelectIcon(macro and macro.StaticTexture)
end

local function SetMacroItems()
	local items = MegaMacro.GetMacrosInScope(SelectedScope)
	MacroItems = items or {}

	local function SortByName(left, right)
		return (left.DisplayName or "") < (right.DisplayName or "")
	end

	table.sort(MacroItems, SortByName)

	-- Macros we don't manage go after the inactive ones. This has to be a copy, the list is saved data.
	if SelectedScope == MegaMacroScopes.Inactive then
		local unmanagedMacros = MegaMacroEngine.GetUnmanagedMacros()
		table.sort(unmanagedMacros, SortByName)

		local inactiveMacros = MacroItems
		MacroItems = {}
		for _, macro in ipairs(inactiveMacros) do
			table.insert(MacroItems, macro)
		end
		for _, macro in ipairs(unmanagedMacros) do
			table.insert(MacroItems, macro)
		end

		CreateMacroSlotFrames(#MacroItems)
		InitializeMacroSlots()
	end

	local newMacroButtonCreated = false
	-- Slots past this are dimmed: they need an ID or game macro that something on the Inactive tab is using
	local lastUsableSlot = #MacroItems
	local slotCount = MegaMacro.GetSlotCount(SelectedScope)

	if SelectedScope ~= MegaMacroScopes.Inactive then
		lastUsableSlot = #MacroItems + MegaMacroEngine.GetAvailableSlotCount(SelectedScope)
	end

	for i=1, CreatedSlotCount do
		local buttonFrame, buttonName, buttonIcon = GetMacroButtonUI(i)

		local macro = MacroItems[i]
		local isBlockedSlot = not macro and SelectedScope ~= MegaMacroScopes.Inactive and i > lastUsableSlot and i <= slotCount
		buttonFrame.IsBlockedSlot = isBlockedSlot
		buttonFrame:SetAlpha(isBlockedSlot and 0.3 or 1)

		if macro and macro.IsUnmanaged then
			buttonFrame.Macro = macro
			buttonFrame.IsNewButton = false
			buttonName:SetText(macro.DisplayName)
			buttonIcon:SetTexture(macro.StaticTexture)
			buttonIcon:SetTexCoord(0, 1, 0, 1)
			buttonIcon:SetAlpha(0.5)
			buttonIcon:SetDesaturated(true)
		elseif macro then
			buttonFrame.Macro = macro
			buttonFrame.IsNewButton = false
			-- buttonFrame:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
			buttonName:SetText(macro.DisplayName)
			MegaMacroIconEvaluator.UpdateMacro(macro)
			local data = MegaMacroIconEvaluator.GetCachedData(macro.Id)
			buttonIcon:SetTexture(data and data.Icon or MegaMacroTexture)
			buttonIcon:SetDesaturated(false)
			buttonIcon:SetTexCoord(0, 1, 0, 1)
			buttonIcon:SetAlpha(1)
			if not MegaMacroEngine.GetMacroIndexFromId(macro.Id) then
				buttonIcon:SetAlpha(0.5)
				buttonIcon:SetDesaturated(true)
			end
		elseif not newMacroButtonCreated and SelectedScope ~= MegaMacroScopes.Inactive and i <= lastUsableSlot then
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

-- Adding and removing macros needs a free macro slot and action bar changes, which have to wait
local function IsBlockedByCombat()
	if InCombatLockdown() then
		print("Mega Macro: You can't do that in combat.")
		return true
	end

	return false
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
	if SelectedMacro ~= nil and not IsBlockedByCombat() then
		if SelectedMacro.IsUnmanaged then
			MegaMacroEngine.DeleteUnmanagedMacro(SelectedMacro)
		else
			MegaMacro.Delete(SelectedMacro)
		end
		SetMacroItems()
	end
end

local function UpdateTooltipIfButtonIsHovered(updatedMacroId)
	local mouseFocus = GetMouseFoci()[1]

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

local function ShowMacroTooltip(owner, macro)
	if macro.IsUnmanaged then
		GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
		GameTooltip:AddLine(macro.DisplayName, 1, 1, 1)
		if macro.IsTextLost then
			GameTooltip:AddLine("Text was lost. Drag to another tab to keep its name, icon and action bar spots, then rewrite it.", nil, nil, nil, true)
		elseif macro.HeldId and macro.HeldId > MacroIndexOffsets.PerClass and macro.HeldId <= MacroIndexOffsets.PerCharacter then
			GameTooltip:AddLine("Saved data is missing. It may be for a different class or spec. Drag to the right tab to import it.", nil, nil, nil, true)
		elseif macro.HeldId then
			GameTooltip:AddLine("Saved data is missing. Drag to another tab to import it.", nil, nil, nil, true)
		else
			GameTooltip:AddLine("Not managed by Mega Macro. Drag it to another tab to import it.", nil, nil, nil, true)
		end
		if macro.HeldId then
			local tabName = macro.HeldId <= MacroIndexOffsets.PerClass and "global"
				or macro.HeldId <= MacroIndexOffsets.PerSpecialization and "class"
				or macro.HeldId <= MacroIndexOffsets.PerCharacter and "specialization"
				or macro.HeldId <= MacroIndexOffsets.Inactive and "character"
			-- One that was already inactive gives no hint where it belongs
			if tabName then
				GameTooltip:AddLine("Came from the " .. tabName .. " tab.", 0.6, 0.6, 0.6, true)
			end
		end
		GameTooltip:Show()
	else
		ShowToolTipForMegaMacro(macro.Id)
	end
end

local function PrintTabIsFull(scope)
	if #MegaMacro.GetMacrosInScope(scope) < MegaMacro.GetSlotCount(scope) then
		print("Mega Macro: There's no room on that tab. Macros on the Inactive tab are taking up its space. Import or delete some of them to free it.")
	else
		print("Mega Macro: That tab is full. Import or delete macros on the Inactive tab to free up space.")
	end
end

local function PickupMegaMacro(macro)
	local macroIndex

	if macro.IsUnmanaged then
		macroIndex = MegaMacroEngine.FindUnmanagedMacroIndex(macro)
	else
		macroIndex = MegaMacroEngine.GetMacroIndexFromId(macro.Id)
	end

	-- highlight all tabs to indicate it can be moved to a tab
	for i=1, 5 do
		if i ~= SelectedTabIndex then
			local tab = _G["MegaMacro_FrameTab"..i]
			tab:LockHighlight()
		end
	end

	if macroIndex then
		PickupMacro(macroIndex)
	end
end

local function HandleReceiveDrag(targetScope)
	local type, macroIndex = GetCursorInfo()

	if type == "macro" then
		if IsBlockedByCombat() then
			ClearCursor()
			return true
		end

		local macroId = MegaMacroEngine.GetMacroIdFromIndex(macroIndex)
		local macro = MegaMacro.GetById(macroId)

		if macro then
			ClearCursor()

			if IsControlKeyDown() then
				local newDisplayName = macro.Scope == targetScope and macro.DisplayName.." copy" or macro.DisplayName
				local newMacro = MegaMacro.Create(newDisplayName, targetScope, macro.StaticTexture)

				if newMacro then
					MegaMacro.UpdateCode(newMacro, macro.Code)
				else
					PrintTabIsFull(targetScope)
				end

				if newMacro and targetScope == SelectedScope then
					SetMacroItems()
					SelectMacro(newMacro)
				end
			elseif targetScope == macro.Scope then
				-- do nothing
			else
				local newMacro = MegaMacro.Move(macro, targetScope)

				if not newMacro then
					PrintTabIsFull(targetScope)
				elseif targetScope == SelectedScope then
					SetMacroItems()
					SelectMacro(newMacro)
				elseif macro.Scope == SelectedScope then
					SetMacroItems()
				end
			end
		elseif macroId and MegaMacro.IsKnownId(macroId) then
			ClearCursor()
			print("Mega Macro: That macro belongs to another class or specialization.")
		elseif targetScope == MegaMacroScopes.Inactive then
			ClearCursor()
			print("Mega Macro: Drag it to another tab to import it.")
		else
			ClearCursor()
			local newMacro = MegaMacroEngine.ImportNativeMacro(macroIndex, targetScope)

			if not newMacro then
				PrintTabIsFull(targetScope)
			end

			SetMacroItems()

			if newMacro and targetScope == SelectedScope then
				SelectMacro(newMacro)
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

local function ShowRecoveryPrompt(info)
	local lines = { "Mega Macro found macros left from an earlier install." }
	local recoverableCount = info.GlobalCount + info.CharacterCount

	table.insert(lines, recoverableCount .. " are global and character macros, which can be fully recovered.")

	if info.ClassOrSpecCount > 0 then
		table.insert(lines, info.ClassOrSpecCount .. " are class or spec macros. Those slots are shared, so they may be for a different class or spec. Review them on the Inactive tab and drag them to the right tab.")
	end

	if info.LostCount > 0 then
		table.insert(lines, info.LostCount .. " lost their text. Only their name and icon are left on the Inactive tab.")
	end

	table.insert(lines, "Recover the " .. recoverableCount .. " global and character macros now?")

	StaticPopupDialogs["MEGAMACRO_RECOVER_MACROS"] = {
		text = "%s",
		button1 = "Recover",
		button2 = "Not now",
		OnAccept = function()
			if not IsBlockedByCombat() then
				local recovered = MegaMacroEngine.RecoverMacros()
				local info = MegaMacroEngine.GetRecoveryInfo()
				MegaMacroGlobalData.RecoverableMacroCount = info.GlobalCount
				MegaMacroCharacterData.RecoverableMacroCount = info.CharacterCount
				print("Mega Macro: Recovered " .. recovered .. " macros.")

				local leftCount = info.GlobalCount + info.CharacterCount
				if leftCount > 0 then
					print("Mega Macro: " .. leftCount .. " didn't fit and are still on the Inactive tab.")
				end

				if MegaMacro_Frame:IsShown() then
					SetMacroItems()
				end
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3, -- to avoid UI taint
	}

	StaticPopup_Show("MEGAMACRO_RECOVER_MACROS", table.concat(lines, "\n\n"))
end

MegaMacroWindow = {
	ShowRecoveryPrompt = ShowRecoveryPrompt,
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
	PanelTemplates_SetNumTabs(MegaMacro_Frame, 6)
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
	MegaMacroIconNavigator.Release()
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
		MegaMacro_ConfigContainer:Hide()
		
		if tabIndex == 6 then
			SelectedScope = 'config'
			MegaMacro_FrameTab_ShowConfig()
			return
		end

		SelectedScope = scope
		SelectedTabIndex = tabIndex

		InitializeMacroSlots()
		SetMacroItems()
		InitializeTabs()

	end
end

function MegaMacro_FrameTab_ShowConfig()
	-- Initialize Config Options
	if not MegaMacro_ConfigContainer.initialized then
		MecaMacro_GenerateConfig()
		MegaMacro_ConfigContainer.initialized = true
	end

	--Clear macro area
	InitializeMacroSlots()
	SelectMacro(nil)

	MegaMacro_ConfigContainer:Show()
end

function MegaMacro_FrameTab_OnReceiveDrag(self)
	local tabIndex = self:GetID()
	local scope = GetScopeFromTabIndex(tabIndex)
	HandleReceiveDrag(scope)
end

function MegaMacro_ButtonContainer_OnLoad()
	CreateMacroSlotFrames(HighestMaxMacroCount)
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
		elseif self.IsNewButton and not IsBlockedByCombat() then
			NewMacro()
		else
			self:SetChecked(false)
		end
	end
end

function MegaMacro_MacroButton_OnEnter(self)
	if self.Macro then
		ShowMacroTooltip(self, self.Macro)
	elseif self.IsBlockedSlot then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Slot in use", 1, 1, 1)
		GameTooltip:AddLine("Macros on the Inactive tab are taking up this space. Import or delete some of them to free it.", nil, nil, nil, true)
		GameTooltip:Show()
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

function MegaMacro_MacroButton_OnDragStop(self)
	for i=1, 5 do
		local tab = _G["MegaMacro_FrameTab"..i]
		tab:UnlockHighlight()
	end
end

function MegaMacro_MacroButton_OnReceiveDrag(self)
	HandleReceiveDrag(SelectedScope)
end

function MegaMacro_FrameSelectedMacroButton_OnEnter()
	if SelectedMacro then
		ShowMacroTooltip(MegaMacro_FrameSelectedMacroButton, SelectedMacro)
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
	if SelectedMacro and not SelectedMacro.IsUnmanaged then
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
	-- Set color of text based on length
	if MegaMacro_FrameText:GetNumLetters() > MegaMacroCodeMaxLength then
		MegaMacro_FrameCharLimitText:SetTextColor(1, 0.267, 0.267)
	elseif MegaMacro_FrameText:GetNumLetters() > MegaMacroCodeMaxLengthForNative then
		MegaMacro_FrameCharLimitText:SetTextColor(1, 0.85, 0)
	else
		MegaMacro_FrameCharLimitText:SetTextColor(1,1,1) --0.2, 0.867, 1.0
	end
	-- Limit. Custom hover tooltip
	MegaMacro_FrameCharLimitText:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
		GameTooltip:AddLine("MegaMacro: Character Limit", 1, 1, 1)
		GameTooltip:AddLine("\nMacros over 250 characters rely on custom macro logic. They will not have a dynamic icon if you are not using MegaMacros icon rendering. This option can be set in the config tab.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	MegaMacro_FrameCharLimitText:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)

	ScrollingEdit_OnTextChanged(self, self:GetParent())
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
		MegaMacro_DisplayNameLabel:SetText("(#"..SelectedMacro.Id .. ") Display Name")
		MegaMacro_PopupFrame:Show()
		PopupMode = PopupModes.Edit
	end
end

function MegaMacro_BlizMacro_Toggle()
	-- re-initialize macros
	MegaMacroEngine.SafeInitialize()
	-- update macro char length limit
	MegaMacro_InitialiseConfig()
	MegaMacro_FrameCharLimitText:SetFormattedText(
		rendering.CharLimitMessageFormat,
		MegaMacro_FrameText:GetNumLetters(),
		MegaMacroCodeMaxLength)
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
		if IsBlockedByCombat() then
			return
		end

		local createdMacro = MegaMacro.Create(enteredText, SelectedScope, SelectedIcon, isStaticTextureFallback)
		SetMacroItems()
		SelectMacro(createdMacro)

		if createdMacro then
			MegaMacro_FrameText:SetFocus()
		else
			PrintTabIsFull(SelectedScope)
		end
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

function MegaMacro_PopupFrame_OnShow()
	MegaMacroIconNavigator.SetSearch(MegaMacro_IconSearchBox:GetText())
end

function MegaMacro_PopupFrame_OnHide()
	MegaMacroIconNavigator.EndSearch()
end

function MegaMacro_PopupFrame_OnUpdate()
	MegaMacroIconNavigator.OnUpdate()

	-- The first slot is always "no icon", followed by the results
	local numMacroIcons = MegaMacroIconNavigator.GetResultCount() + 1;
	local macroPopupIcon, macroPopupButton;
	local macroPopupOffset = FauxScrollFrame_GetOffset(MegaMacro_PopupScrollFrame);
	local index;

	-- Icon list
	for i=1, NUM_MACRO_ICONS_SHOWN do
		macroPopupButton = _G["MegaMacro_PopupButton"..i];
		macroPopupIcon = _G["MegaMacro_PopupButton"..i.."Icon"];
		index = (macroPopupOffset * NUM_ICONS_PER_ROW) + i;
		local icon, spellId

		if index == 1 then
			icon = MegaMacroTexture
		elseif index <= numMacroIcons then
			icon, spellId = MegaMacroIconNavigator.GetResult(index - 1)
		end

		if icon then
			macroPopupIcon:SetTexture(icon);
			macroPopupButton.SpellId = spellId
			macroPopupButton:Show();
		else
			macroPopupIcon:SetTexture("");
			macroPopupButton.SpellId = nil
			macroPopupButton:Hide();
		end

		macroPopupButton:SetChecked(icon and SelectedIcon == icon)
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

	if MegaMacro_PopupFrame:IsShown() then
		MegaMacroIconNavigator.SetSearch(MegaMacro_IconSearchBox:GetText())
	end
end

-- The game only inserts shift-clicked links into its own macro window, so do the same for ours.
-- Everything that can be shift-clicked (spellbook, bags, toys, character page) ends up here.
function MegaMacro_RegisterShiftClicks()
	hooksecurefunc(ChatFrameUtil, "InsertLink", function(text)
		if not text or not MegaMacro_FrameText:HasFocus() then
			return
		end

		local isItem = string.find(text, "item:", 1, true) ~= nil
		local name = isItem and C_Item.GetItemInfo(text) or string.match(text, "%[(.-)%]") or text
		local cursorPosition = MegaMacro_FrameText:GetCursorPosition()
		local isLineStart = cursorPosition == 0 or string.sub(MegaMacro_FrameText:GetText(), cursorPosition, cursorPosition) == "\n"

		if not isLineStart then
			MegaMacro_FrameText:Insert(name)
		elseif not isItem then
			MegaMacro_FrameText:Insert(SLASH_CAST1.." "..name.."\n")
		elseif C_Item.GetItemSpell(text) then
			MegaMacro_FrameText:Insert(SLASH_USE1.." "..name.."\n")
		else
			MegaMacro_FrameText:Insert(SLASH_EQUIP1.." "..name.."\n")
		end
	end)
end

-- Create the Config options
function MecaMacro_GenerateConfig()
    -- Blizzard Action Bar Icons
    if not MegaMacroIsForever then
        MecaMacroConfig_GenerateCheckbox('UseBlizzardActionIcons', 'Blizzard Action Bar Icons', 'Disable Mega Macro Action Bar Engine. \nMacro Icons will be decided by blizzard instead of Mega Macro.', 0, -5, MegaMacroConfig.UseNativeActionBar, function(value)
            MegaMacroConfig.UseNativeActionBar = value
        end)
    end
	-- Make button "Uninstall"
	MecaMacroConfig_GenerateButton('Uninstall', 'Uninstall', 'Removes MegaMacro information from Macros. Disable MegaMacro before reload to avoid re-importing them. \n\nNote: Current Class and Spec macros will become global. \nMacros for other Classes and Specs will be lost since Blizzard Macros do not have room for them.', 0, MegaMacroIsForever and -5 or -30, function()
		-- Warn and get confirmation
		StaticPopupDialogs["MEGAMACRO_UNINSTALL_WARNING"] = {
			text = "Are you sure you want to uninstall MegaMacro?",
			button1 = "Yes",
			button2 = "No",
			OnAccept = function()
				if not IsBlockedByCombat() then
					MegaMacroEngine.Uninstall()
					print("MegaMacro uninstalled.")
				end
			end,
			OnCancel = function()
				print("Uninstallation cancelled.")
			end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3, -- to avoid UI taint
		}

		StaticPopup_Show("MEGAMACRO_UNINSTALL_WARNING")
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

function MecaMacroConfig_GenerateButton(name, text, tooltip, x, y, onClick)
	local button = CreateFrame("Button", "MegaMacro_ConfigContainer_" .. name, MegaMacro_ConfigContainer, "UIPanelButtonTemplate")
	button:SetPoint("TOPLEFT", x, y)
	-- set width
	button:SetWidth(100)
	button:SetScript("OnClick", function(self)
		onClick()
	end)
	button.tooltipText = tooltip
	
	local textFrame = _G[button:GetName() .. "Text"]
	textFrame:SetFontObject("GameFontNormalSmall")
	textFrame:SetText(text)

	return button
end
