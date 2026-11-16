-- The Options tab (settings and backups) and the window that shows and takes share codes

local RowHeight = 20
local DateFormat = "%Y-%m-%d %H:%M"

local TypeLabels = {
	Manual = "Manual",
	Automatic = "Automatic",
	BeforeRestore = "Before restore",
	BeforeUninstall = "Before uninstall",
	Imported = "Imported"
}

-- What the Options tab covers. Everything else in the window belongs to the macro tabs.
local MacroTabElements = {
	"MegaMacro_ButtonScrollFrame",
	"MegaMacro_HorizontalBarLeft",
	"MegaMacro_HorizontalBarRight",
	"MegaMacro_FrameSelectedMacroBackground",
	"MegaMacro_FrameSelectedMacroName",
	"MegaMacro_FrameEnterMacroText",
	"MegaMacro_FrameCharLimitText",
	"MegaMacro_FrameSelectedMacroButton",
	"MegaMacro_EditButton",
	"MegaMacro_FrameScrollFrame",
	"MegaMacro_FrameTextButton",
	"MegaMacro_CancelButton",
	"MegaMacro_SaveButton",
	"MacroFrameTextBackground",
	"MegaMacro_DeleteButton",
	"MegaMacro_ExportTabButton",
	"MegaMacro_ImportButton"
}

local Panel
local Rows = {}
local SelectedBackup
local Buttons = {}

local function GetBackupLabel(backup)
	local label = backup.Name or TypeLabels[backup.Type] or ""

	if backup.Name and backup.Type == MegaMacroBackups.Types.Imported then
		label = label .. " (imported)"
	end

	return label
end

local function GetBackupDate(backup)
	return date(DateFormat, backup.Time)
end

local function GetPopupEditBox(dialog)
	return dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
end

local function UpdateButtons()
	local hasSelection = SelectedBackup ~= nil
	Buttons.Restore:SetEnabled(hasSelection)
	Buttons.Export:SetEnabled(hasSelection)
	Buttons.Delete:SetEnabled(hasSelection)
end

local function CreateRow(index)
	local row = CreateFrame("Button", nil, Panel.ListChild)
	row:SetHeight(RowHeight)
	row:SetPoint("TOPLEFT", 0, -(index - 1) * RowHeight)
	row:SetPoint("RIGHT", Panel.ListChild, "RIGHT", 0, 0)
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

	row.Selected = row:CreateTexture(nil, "BACKGROUND")
	row.Selected:SetAllPoints()
	row.Selected:SetColorTexture(1, 0.82, 0, 0.25)
	row.Selected:Hide()

	local function AddColumn(x, width, justify)
		local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		text:SetPoint("LEFT", x, 0)
		text:SetWidth(width)
		text:SetJustifyH(justify or "LEFT")
		text:SetWordWrap(false)
		return text
	end

	row.Date = AddColumn(6, 110)
	row.Label = AddColumn(122, 190)
	row.Character = AddColumn(318, 180)
	row.Count = AddColumn(502, 60, "RIGHT")

	row:SetScript("OnClick", function(self)
		SelectedBackup = self.Backup
		MegaMacroOptions.Refresh()
	end)

	-- Long names and realms get cut off in the columns
	row:SetScript("OnEnter", function(self)
		if self.Backup then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(GetBackupLabel(self.Backup), 1, 1, 1)
			GameTooltip:AddLine(GetBackupDate(self.Backup))
			if self.Backup.Character then
				GameTooltip:AddLine(self.Backup.Character)
			end
			GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)

	Rows[index] = row
	return row
end

local function RefreshList()
	local backups = MegaMacroBackups.GetAll()
	local isSelectionListed = false

	for index, backup in ipairs(backups) do
		local row = Rows[index] or CreateRow(index)
		row.Backup = backup
		row.Date:SetText(GetBackupDate(backup))
		row.Label:SetText(GetBackupLabel(backup))
		row.Character:SetText(backup.Character or "")
		row.Count:SetText(backup.Count or "")
		row.Selected:SetShown(backup == SelectedBackup)
		row:Show()
		isSelectionListed = isSelectionListed or backup == SelectedBackup
	end

	for index=#backups + 1, #Rows do
		Rows[index].Backup = nil
		Rows[index]:Hide()
	end

	if not isSelectionListed then
		SelectedBackup = nil
	end

	Panel.ListChild:SetHeight(math.max(#backups * RowHeight, 1))
	Panel.EmptyText:SetShown(#backups == 0)
	UpdateButtons()
end

local function CreateButton(text, width, onClick)
	local button = CreateFrame("Button", nil, Panel, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	return button
end

local function CreateCheckbox(name, text, tooltip, checked, onClick)
	local checkbox = CreateFrame("CheckButton", "MegaMacro_Options" .. name, Panel, "ChatConfigCheckButtonTemplate")
	checkbox:SetChecked(checked)
	checkbox.tooltip = tooltip
	checkbox:SetScript("OnClick", function(self)
		onClick(self:GetChecked() and true or false)
	end)

	local label = _G[checkbox:GetName() .. "Text"]
	label:SetFontObject("GameFontHighlightSmall")
	label:SetText(text)

	return checkbox
end

-- Asks which tabs to put back, then restores just those
local RestoreDialog
local RestoreBackup

local function CreateDialogFrame(name, width, height)
	local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
	frame:SetSize(width, height)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 }
	})

	-- The dialog background is see-through, which makes text hard to read over the window behind
	local shade = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
	shade:SetPoint("TOPLEFT", 11, -12)
	shade:SetPoint("BOTTOMRIGHT", -12, 11)
	shade:SetColorTexture(0, 0, 0, 0.85)

	frame:Hide()
	tinsert(UISpecialFrames, name)
	return frame
end

-- In the order the tabs appear
local RestorePartOrder = { "Global", "Class", "Specializations", "Character", "Inactive", "OtherClasses" }

local function GetRestorePartLabel(part)
	if part == "Class" then
		return MegaMacroCachedClass
	elseif part == "Specializations" then
		return MegaMacroCachedClass .. " specs"
	elseif part == "Character" then
		return UnitName("player")
	elseif part == "OtherClasses" then
		return "Other classes"
	end

	return part
end

local function UpdateRestoreButton()
	local anyChecked = false

	for _, row in pairs(RestoreDialog.Rows) do
		anyChecked = anyChecked or (row:IsEnabled() and row:GetChecked())
	end

	RestoreDialog.RestoreButton:SetEnabled(anyChecked)
end

local function RestoreChecked()
	local backup = RestoreBackup

	if not backup or MegaMacroWindow.IsBlockedByCombat() then
		return
	end

	local parts = {}
	for part, row in pairs(RestoreDialog.Rows) do
		parts[MegaMacroBackups.RestoreParts[part]] = row:IsEnabled() and row:GetChecked() or nil
	end

	RestoreDialog:Hide()

	if MegaMacroBackups.Restore(backup, parts) then
		print("Mega Macro: Restored the backup from " .. GetBackupDate(backup) .. ".")
	else
		print("Mega Macro: That backup couldn't be read.")
	end

	MegaMacroOptions.Refresh()
end

local function CreateRestoreDialog()
	RestoreDialog = CreateDialogFrame("MegaMacro_RestoreDialog", 380, 120 + #RestorePartOrder * 24)

	RestoreDialog.Title = RestoreDialog:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	RestoreDialog.Title:SetPoint("TOP", 0, -20)

	local message = RestoreDialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	message:SetPoint("TOP", RestoreDialog.Title, "BOTTOM", 0, -8)
	message:SetWidth(330)
	message:SetText("Choose which tabs to restore. Your macros are backed up first, so you can undo this.")

	RestoreDialog.Rows = {}

	for index, part in ipairs(RestorePartOrder) do
		local row = CreateFrame("CheckButton", "MegaMacro_RestorePart" .. part, RestoreDialog, "ChatConfigCheckButtonTemplate")
		row:SetPoint("TOPLEFT", 28, -64 - (index - 1) * 24)
		row:SetScript("OnClick", UpdateRestoreButton)

		row.Label = _G[row:GetName() .. "Text"]
		row.Label:SetFontObject("GameFontHighlightSmall")

		row.Count = RestoreDialog:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		row.Count:SetPoint("RIGHT", RestoreDialog, "RIGHT", -30, 0)
		row.Count:SetPoint("TOP", row, "TOP", 0, -6)
		row.Count:SetWidth(210)
		row.Count:SetJustifyH("RIGHT")
		row.Count:SetWordWrap(false)

		RestoreDialog.Rows[part] = row
	end

	RestoreDialog.CancelButton = CreateFrame("Button", nil, RestoreDialog, "UIPanelButtonTemplate")
	RestoreDialog.CancelButton:SetSize(100, 22)
	RestoreDialog.CancelButton:SetPoint("BOTTOMRIGHT", -20, 20)
	RestoreDialog.CancelButton:SetText(CANCEL)
	RestoreDialog.CancelButton:SetScript("OnClick", function() RestoreDialog:Hide() end)

	RestoreDialog.RestoreButton = CreateFrame("Button", nil, RestoreDialog, "UIPanelButtonTemplate")
	RestoreDialog.RestoreButton:SetSize(100, 22)
	RestoreDialog.RestoreButton:SetPoint("RIGHT", RestoreDialog.CancelButton, "LEFT", -6, 0)
	RestoreDialog.RestoreButton:SetText("Restore")
	RestoreDialog.RestoreButton:SetScript("OnClick", RestoreChecked)
end

local function RestoreSelected()
	local backup = SelectedBackup

	if not backup or MegaMacroWindow.IsBlockedByCombat() then
		return
	end

	local info = MegaMacroBackups.GetRestoreInfo(backup)

	if not info then
		print("Mega Macro: That backup couldn't be read.")
		return
	end

	if not RestoreDialog then
		CreateRestoreDialog()
	end

	RestoreBackup = backup
	RestoreDialog.Title:SetText("Restore the backup from " .. GetBackupDate(backup))

	for part, row in pairs(RestoreDialog.Rows) do
		local count = info.Counts[MegaMacroBackups.RestoreParts[part]]
		local countText = count == 0 and "Empty" or count == 1 and "1 macro" or count .. " macros"
		local isAvailable = part ~= "Character" or info.HasCharacter
		-- Another character's tab replaces this one's, so it's only put on when asked for
		local isOtherCharacter = part == "Character" and not info.IsSameCharacter

		row:SetEnabled(isAvailable)
		row:SetChecked(isAvailable and not isOtherCharacter)
		row.Label:SetText(GetRestorePartLabel(part))
		row.Label:SetTextColor(isAvailable and 1 or 0.5, isAvailable and 1 or 0.5, isAvailable and 1 or 0.5)

		if not isAvailable then
			row.Count:SetText("")
		elseif isOtherCharacter then
			row.Count:SetText(countText .. ", from " .. (info.CharacterName or "another character"))
		else
			row.Count:SetText(countText)
		end
	end

	UpdateRestoreButton()
	RestoreDialog:Show()
end

local function DeleteSelected()
	local backup = SelectedBackup

	if not backup then
		return
	end

	StaticPopupDialogs["MEGAMACRO_DELETE_BACKUP"] = {
		text = "Delete the backup from " .. GetBackupDate(backup) .. "?",
		button1 = DELETE or "Delete",
		button2 = CANCEL,
		OnAccept = function()
			MegaMacroBackups.Delete(backup)
			MegaMacroOptions.Refresh()
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3
	}

	StaticPopup_Show("MEGAMACRO_DELETE_BACKUP")
end

local function BackUpNow()
	local function Create(dialog)
		local editBox = GetPopupEditBox(dialog)
		SelectedBackup = MegaMacroBackups.Create(editBox and editBox:GetText() or "")
		dialog:Hide()
		MegaMacroOptions.Refresh()
	end

	StaticPopupDialogs["MEGAMACRO_NAME_BACKUP"] = {
		text = "Name this backup (optional):",
		button1 = "Back Up",
		button2 = CANCEL,
		hasEditBox = true,
		maxLetters = 40,
		OnShow = function(dialog)
			local editBox = GetPopupEditBox(dialog)
			if editBox then
				editBox:SetText("")
				editBox:SetFocus()
			end
		end,
		OnAccept = Create,
		EditBoxOnEnterPressed = function(editBox) Create(editBox:GetParent()) end,
		EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3
	}

	StaticPopup_Show("MEGAMACRO_NAME_BACKUP")
end

local function ConfirmUninstall()
	if MegaMacroWindow.IsBlockedByCombat() then
		return
	end

	-- The tabs as they're named right now, so the player knows exactly which macros stay
	local keptTabs = MegaMacro_FrameTab1:GetText() .. ", " .. MegaMacro_FrameTab2:GetText() .. ", "
		.. MegaMacro_FrameTab3:GetText() .. " and " .. MegaMacro_FrameTab4:GetText()

	StaticPopupDialogs["MEGAMACRO_UNINSTALL_WARNING"] = {
		text = "Uninstall Mega Macro?\n\nYour " .. keptTabs .. " macros become normal game macros. "
			.. "Macros for your other classes and specs, and on the Inactive tab, don't fit in the game's macro list and are left out.\n\n"
			.. "Everything is backed up first, so you can restore it if you come back.\n\n"
			.. "Afterwards, disable Mega Macro and reload, or it will take over your macros again.",
		button1 = "Uninstall",
		button2 = CANCEL,
		OnAccept = function()
			if not MegaMacroWindow.IsBlockedByCombat() then
				MegaMacroBackups.CreateBeforeUninstall()
				MegaMacroEngine.Uninstall()
				MegaMacroOptions.Refresh()
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3
	}

	StaticPopup_Show("MEGAMACRO_UNINSTALL_WARNING")
end

local function CreatePanel()
	Panel = CreateFrame("Frame", "MegaMacro_OptionsPanel", MegaMacro_Frame)
	Panel:SetPoint("TOPLEFT", 14, -66)
	Panel:SetPoint("BOTTOMRIGHT", -14, 30)
	Panel:Hide()

	local title = Panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 0, 0)
	title:SetText("Backups")

	local description = Panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	description:SetText("A backup holds all the macros of the character who made it. You can choose which tabs to restore.")

	local listBox = CreateFrame("Frame", nil, Panel, "TooltipBackdropTemplate")
	listBox:SetPoint("TOPLEFT", 0, -60)
	listBox:SetPoint("RIGHT", Panel, "RIGHT", 0, 0)
	listBox:SetHeight(192)

	local function AddHeader(text, x, width, justify)
		local header = Panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		header:SetPoint("BOTTOMLEFT", listBox, "TOPLEFT", x + 6, 3)
		header:SetWidth(width)
		header:SetJustifyH(justify or "LEFT")
		header:SetText(text)
	end

	AddHeader("Date", 6, 110)
	AddHeader("Name", 122, 190)
	AddHeader("Character", 318, 180)
	AddHeader("Macros", 502, 60, "RIGHT")

	local scrollFrame = CreateFrame("ScrollFrame", "MegaMacro_BackupScrollFrame", listBox, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 6, -6)
	scrollFrame:SetPoint("BOTTOMRIGHT", -28, 6)

	Panel.ListChild = CreateFrame("Frame", nil, scrollFrame)
	Panel.ListChild:SetSize(570, 1)
	scrollFrame:SetScrollChild(Panel.ListChild)

	Panel.EmptyText = listBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	Panel.EmptyText:SetPoint("CENTER")
	Panel.EmptyText:SetText("No backups yet.")

	Buttons.BackUp = CreateButton("Back Up Now", 110, BackUpNow)
	Buttons.BackUp:SetPoint("TOPLEFT", listBox, "BOTTOMLEFT", 0, -6)

	Buttons.Restore = CreateButton("Restore", 90, RestoreSelected)
	Buttons.Restore:SetPoint("LEFT", Buttons.BackUp, "RIGHT", 4, 0)

	Buttons.Export = CreateButton("Export", 90, function()
		if SelectedBackup then
			MegaMacroCodeDialog.ShowCode("Backup from " .. GetBackupDate(SelectedBackup), SelectedBackup.Code)
		end
	end)
	Buttons.Export:SetPoint("LEFT", Buttons.Restore, "RIGHT", 4, 0)

	Buttons.Delete = CreateButton(DELETE or "Delete", 90, DeleteSelected)
	Buttons.Delete:SetPoint("LEFT", Buttons.Export, "RIGHT", 4, 0)

	Buttons.Import = CreateButton("Import", 90, function()
		MegaMacroCodeDialog.ShowImport(nil)
	end)
	Buttons.Import:SetPoint("TOPRIGHT", listBox, "BOTTOMRIGHT", 0, -6)

	local automatic = CreateCheckbox("AutomaticBackups", "Back up automatically", nil,
		MegaMacroConfig.AutomaticBackups, function(value)
			MegaMacroConfig.AutomaticBackups = value
		end)
	automatic:SetPoint("TOPLEFT", Buttons.BackUp, "BOTTOMLEFT", -2, -10)

	local automaticDescription = Panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	automaticDescription:SetPoint("TOPLEFT", automatic, "BOTTOMLEFT", 26, 4)
	automaticDescription:SetPoint("RIGHT", Panel, "RIGHT", 0, 0)
	automaticDescription:SetJustifyH("LEFT")
	automaticDescription:SetText("Once a day at login, if your macros changed. Keeps daily ones for a week, weekly for a month, monthly for six months.")

	local generalTitle = Panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	generalTitle:SetPoint("TOPLEFT", automaticDescription, "BOTTOMLEFT", -24, -16)
	generalTitle:SetText("General")

	local livePreview = CreateCheckbox("LivePreview", "Fade macro conditionals",
		"In the macro editor, lines and options that wouldn't run with your current target, modifier keys, form and so on are faded out. Updates as things change.",
		MegaMacroConfig.LivePreview ~= false, function(value)
			MegaMacroConfig.LivePreview = value
			MegaMacroEditorInsights.Refresh()
		end)
	livePreview:SetPoint("TOPLEFT", generalTitle, "BOTTOMLEFT", -2, -6)

	local hoverHelp = CreateCheckbox("HoverHelp", "Explain macro text on hover",
		"Point at a condition, target, spell or command in the macro editor to see what it means and whether it's true right now. Shows which form each stance number is on this character.",
		MegaMacroConfig.HoverHelp ~= false, function(value)
			MegaMacroConfig.HoverHelp = value
		end)
	hoverHelp:SetPoint("TOPLEFT", livePreview, "BOTTOMLEFT", 0, 2)

	-- The game draws the action bars on Forever
	if not MegaMacroIsForever then
		local blizzardIcons = CreateCheckbox("UseBlizzardActionIcons", "Blizzard Action Bar Icons",
			"Disable Mega Macro Action Bar Engine. \nMacro Icons will be decided by blizzard instead of Mega Macro.",
			MegaMacroConfig.UseNativeActionBar, function(value)
				MegaMacroConfig.UseNativeActionBar = value
			end)
		blizzardIcons:SetPoint("TOPLEFT", hoverHelp, "BOTTOMLEFT", 0, 2)
	end

	-- Sits in the bottom button row, where Delete is on the macro tabs
	local uninstall = CreateButton("Uninstall", 100, ConfirmUninstall)
	uninstall:SetPoint("BOTTOMLEFT", MegaMacro_Frame, "BOTTOMLEFT", 4, 4)

	local uninstallDescription = Panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	uninstallDescription:SetPoint("LEFT", uninstall, "RIGHT", 8, 0)
	uninstallDescription:SetText("Turns your macros back into normal game macros.")
end

MegaMacroOptions = {
	Show = function()
		if not Panel then
			CreatePanel()
		end

		for _, name in ipairs(MacroTabElements) do
			if _G[name] then
				_G[name]:Hide()
			end
		end

		Panel:Show()
		MegaMacroOptions.Refresh()
	end,
	Hide = function()
		if not Panel or not Panel:IsShown() then
			return
		end

		Panel:Hide()

		for _, name in ipairs(MacroTabElements) do
			if _G[name] then
				_G[name]:Show()
			end
		end
	end,
	Refresh = function()
		if Panel and Panel:IsShown() then
			RefreshList()
		end
	end
}

-- Shows a code to copy, or takes one to import
local Dialog
local DialogCode
local ImportScope

local function SetDialogMessage(text, isError)
	Dialog.Message:SetText(text)

	if isError then
		Dialog.Message:SetTextColor(1, 0.3, 0.3)
	else
		Dialog.Message:SetTextColor(1, 1, 1)
	end
end

local function ImportCode()
	if MegaMacroWindow.IsBlockedByCombat() then
		SetDialogMessage("You can't do that in combat.", true)
		return
	end

	local text = Dialog.EditBox:GetText()

	-- Macros need a tab to go on. From Options there isn't one, and guessing could put them on the
	-- wrong class or spec. A backup only goes on the backup list, so it's fine from anywhere.
	if not ImportScope then
		local kind = MegaMacroBackups.GetCodeKind(text)

		if kind == "Macro" then
			SetDialogMessage("This is a macro. Open the tab you want it on and use Import there.", true)
			return
		elseif kind == "Macros" then
			SetDialogMessage("This is a tab of macros. Open the tab you want them on and use Import there.", true)
			return
		end
	end

	local result, value = MegaMacroBackups.Import(text, ImportScope)

	if result == "Macro" then
		if value.Scope == MegaMacroScopes.Inactive and ImportScope ~= MegaMacroScopes.Inactive then
			print("Mega Macro: Added " .. value.DisplayName .. " to the Inactive tab. Drag it to another tab to use it.")
		else
			print("Mega Macro: Added " .. value.DisplayName .. ".")
		end

		Dialog:Hide()
		MegaMacroWindow.ShowMacro(value)
	elseif result == "Macros" then
		local message = "Mega Macro: Added " .. (value.Added + value.OnInactive) .. " macros."

		if value.OnInactive > 0 then
			message = message .. " " .. value.OnInactive .. " didn't fit, so they're on the Inactive tab."
		end

		if value.Skipped > 0 then
			message = message .. " " .. value.Skipped .. " were left out because the Inactive tab is full."
		end

		print(message)
		Dialog:Hide()
		MegaMacroWindow.ShowMacro(nil)
	elseif result == "Backup" then
		print("Mega Macro: Added the backup from " .. GetBackupDate(value) .. " to the list on the Options tab. Restore it from there.")
		Dialog:Hide()
		MegaMacroOptions.Refresh()
	elseif result == "Duplicate" then
		SetDialogMessage("That backup is already on the list.", true)
	elseif result == "Full" then
		SetDialogMessage("There's no room for it. Delete or move macros on the Inactive tab to make room.", true)
	else
		SetDialogMessage("That isn't a Mega Macro code.", true)
	end
end

local function CreateDialog()
	Dialog = CreateDialogFrame("MegaMacro_CodeDialog", 520, 330)

	Dialog.Title = Dialog:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	Dialog.Title:SetPoint("TOP", 0, -20)

	Dialog.Message = Dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	Dialog.Message:SetPoint("TOP", Dialog.Title, "BOTTOM", 0, -8)
	Dialog.Message:SetWidth(470)

	local box = CreateFrame("Frame", nil, Dialog, "TooltipBackdropTemplate")
	box:SetPoint("TOPLEFT", 20, -62)
	box:SetPoint("BOTTOMRIGHT", -20, 50)

	local scrollFrame = CreateFrame("ScrollFrame", "MegaMacro_CodeDialogScrollFrame", box, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 8, -8)
	scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

	Dialog.EditBox = CreateFrame("EditBox", nil, scrollFrame)
	Dialog.EditBox:SetMultiLine(true)
	Dialog.EditBox:SetAutoFocus(false)
	Dialog.EditBox:SetMaxLetters(0)
	Dialog.EditBox:SetFontObject(ChatFontNormal)
	Dialog.EditBox:SetWidth(440)
	scrollFrame:SetScrollChild(Dialog.EditBox)

	-- Clicking anywhere in the box puts the cursor in it
	box:EnableMouse(true)
	box:SetScript("OnMouseDown", function() Dialog.EditBox:SetFocus() end)

	Dialog.EditBox:SetScript("OnEscapePressed", function() Dialog:Hide() end)
	Dialog.EditBox:SetScript("OnTextChanged", function(self, isUserInput)
		if DialogCode then
			-- A code to copy stays as it is, so a stray key press can't spoil it
			if isUserInput then
				self:SetText(DialogCode)
				self:HighlightText()
			end
		else
			Dialog.ActionButton:SetEnabled(string.find(self:GetText(), "%S") ~= nil)
		end
	end)
	Dialog.EditBox:SetScript("OnEditFocusGained", function(self)
		if DialogCode then
			self:HighlightText()
		end
	end)

	Dialog.CloseButton = CreateFrame("Button", nil, Dialog, "UIPanelButtonTemplate")
	Dialog.CloseButton:SetSize(100, 22)
	Dialog.CloseButton:SetPoint("BOTTOMRIGHT", -20, 20)
	Dialog.CloseButton:SetText(CLOSE or "Close")
	Dialog.CloseButton:SetScript("OnClick", function() Dialog:Hide() end)

	Dialog.ActionButton = CreateFrame("Button", nil, Dialog, "UIPanelButtonTemplate")
	Dialog.ActionButton:SetSize(100, 22)
	Dialog.ActionButton:SetPoint("RIGHT", Dialog.CloseButton, "LEFT", -6, 0)
	Dialog.ActionButton:SetText("Import")
	Dialog.ActionButton:SetScript("OnClick", ImportCode)
end

MegaMacroCodeDialog = {
	ShowCode = function(title, code)
		if not Dialog then
			CreateDialog()
		end

		DialogCode = code
		Dialog.Title:SetText(title)
		SetDialogMessage("Press Ctrl+C to copy the code, then paste it with Import in Mega Macro.")
		Dialog.ActionButton:Hide()
		Dialog:Show()
		Dialog.EditBox:SetText(code)
		Dialog.EditBox:SetFocus()
		Dialog.EditBox:HighlightText()
	end,
	ShowImport = function(scope)
		if not Dialog then
			CreateDialog()
		end

		DialogCode = nil
		ImportScope = scope
		Dialog.Title:SetText("Import")
		if scope then
			SetDialogMessage("Paste an exported code with Ctrl+V.")
		else
			SetDialogMessage("Paste a backup code with Ctrl+V.")
		end
		Dialog.ActionButton:Show()
		Dialog.ActionButton:Disable()
		Dialog:Show()
		Dialog.EditBox:SetText("")
		Dialog.EditBox:SetFocus()
	end
}
