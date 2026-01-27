-- THIS FILE IS NOT PUBLISHED

-- This file is here to define WoW and UI globals that are not declared in code
-- so that syntax analysers can react favourably to it.

UIPanelWindows = {}
StaticPopupDialogs = {}
PANEL_DEFAULT_WIDTH = 1 and PANEL_DEFAULT_WIDTH
OKAY = 1 and OKAY
CANCEL = 1 and CANCEL
CONFIRM_DELETE_MACRO = ""
SOUNDKIT = {}
mod = mod
UIParent = {}
SlashCmdList = {}
BOOKTYPE_SPELL = "spell"
BOOKTYPE_PET = "pet"
GameTooltip = {}
ANCHOR_TOPRIGHT = nil
ANCHOR_RIGHT = nil
ANCHOR_BOTTOMRIGHT = nil
ANCHOR_TOPLEFT = nil
ANCHOR_LEFT = nil
ANCHOR_BOTTOMLEFT = nil
ANCHOR_CURSOR = nil
ANCHOR_PRESERVE = nil
ANCHOR_NONE = nil

GetCVar = function(variable) end
LibStub = function(major, minor) major._ = minor end
ShowUIPanel = function(panel) panel._ = nil end
CreateFrame = function(type, name, parent, template) type._ = name + parent + template; return nil end
PanelTemplates_SetTab = function(frame, tabId) frame._ = tabId end
PanelTemplates_SetNumTabs = function(frame, tabId) frame._ = tabId end
ScrollingEdit_OnTextChanged = function(target, parent) target._ = parent end
PlaySound = function(soundId) soundId._ = nil end
GetSpecialization = function() end
GetSpecializationInfo = function(index) index._ = nil end
UnitClass = function(unit) unit._ = nil end
SecureCmdOptionParse = function(options) options._ = nil end
GetMouseFocus = function() end
message = function(text) text._ = nil end
InCombatLockdown = function() end
ActionButton_UpdateAction = function(self, force) self._ = force end
ActionButton_SetTooltip = function(self) self._ = nil end
GetActionInfo = function(actionId) actionId._ = nil end
ActionButton_CalculateAction = function(self) self._ = nil end
PickupMacro = function(macroIndexOrName) macroIndexOrName._ = nil end
IsCurrentAction = function(action) action._ = nil end
GetShapeshiftForm = function(flag) flag._ = nil end
GetShapeshiftFormInfo = function(index) index._ = nil end
UnitBuff = function(unit, buffIndexOrName, filter) unit[buffIndexOrName] = filter end
IsUsableAction = function(action) action._ = nil end
IsActionInRange = function(action) action._ = nil end
ShowMacroFrame = function() end
GetInventoryItemID = function(unit, slotId) unit._ = slotId end
GetActionCooldown = function(action) action._ = nil end
GetActionCount = function(action) action._ = nil end
GetActionTexture = function(action) action._ = nil end
GetActionCharges = function(action) action._ = nil end
IsEquippedAction = function(action) action._ = nil end
PutItemInBackpack = function() end
ClearCursor = function() end
GetCursorInfo = function() end
IsControlKeyDown = function() end
IsAltKeyDown = function() end
IsShiftKeyDown = function() end
PlaceAction = function(slot) slot._ = nil end
IsAutoRepeatAction = function(action) action._ = nil end
tContains = function(table, value) return true end

-- 12.0 NAMESPACE UPDATES

C_Spell = {
    GetSpellInfo = function(spellIdOrName) spellIdOrName._ = nil end,
    GetSpellTexture = function(spellIdOrName) spellIdOrName._ = nil end,
    GetSpellCooldown = function(spellID) spellID._ = nil end,
    GetSpellCharges = function(spellID) spellID._ = nil end,
    GetSpellCastCount = function(spellID) spellID._ = nil end,
    IsSpellUsable = function(spellID) spellID._ = nil end,
    IsCurrentSpell = function(spellID) spellID._ = nil end,
    IsAutoRepeatSpell = function(spellId) spellId._ = nil end,
    GetSpellLossOfControlCooldown = function(spellID) spellID._ = nil end,
    IsSpellInRange = function(spellId, target) spellId._ = target end,
    GetFlyoutInfo = function(flyoutID) flyoutID._ = nil end,
    GetFlyoutSlotInfo = function(flyoutID, slot) flyoutID._ = slot end,
}

C_Item = {
    GetItemInfo = function(itemIdOrName) itemIdOrName._ = nil end,
    GetItemInfoInstant = function(itemIdOrName) itemIdOrName._ = nil end,
    GetItemCooldown = function(itemID) itemID._ = nil end,
    GetItemCount = function(itemID, includeBank, includeCharges) itemID._ = nil end,
    IsCurrentItem = function(itemID) itemID._ = nil end,
    IsUsableItem = function(itemID) itemID._ = nil end,
    IsItemInRange = function(itemID, target) itemID._ = target end,
    GetItemSpell = function(itemIdOrName) itemIdOrName._ = nil end,
    IsEquippedItem = function(itemID) itemID._ = nil end,
    IsEquippableItem = function(itemID) itemID._ = nil end,
    IsConsumableItem = function(itemID) itemID._ = nil end,
}

C_Macro = {
    GetNumMacros = function() end,
    GetMacroBody = function(macroIndexOrName) macroIndexOrName._ = nil end,
    GetMacroInfo = function(macroIndexOrName) macroIndexOrName._ = nil end,
    EditMacro = function(macroIndexOrName, name, icon, body, isLocal, perCharacter) end,
    DeleteMacro = function(macroIndexOrName) macroIndexOrName._ = nil end,
    CreateMacro = function(name, iconFileName, body, perCharacter) return 0 end,
    GetMacroIcons = function(icons) icons._ = nil end,
    GetMacroItemIcons = function(icons) icons._ = nil end,
    GetLooseMacroIcons = function(icons) icons._ = nil end,
    GetLooseMacroItemIcons = function(icons) icons._ = nil end,
}

C_LevelLink = {
    IsSpellLocked = function(spellID) spellID._ = nil end
}

C_SpellBook = {
    GetNumSpellBookSkillLines = function() end,
    GetSpellBookSkillLineInfo = function(index) index._ = nil end,
    GetSpellBookItemType = function(index, bank) index._ = bank end,
    GetSpellBookItemTexture = function(index, bank) index._ = bank end,
}

MegaMacro_Frame = {}
MegaMacro_ButtonContainer = {}
MegaMacro_FrameText = {}
MegaMacro_FrameSelectedMacroName = {}
MegaMacro_FrameSelectedMacroButtonIcon = {}
MegaMacro_SaveButton = {}
MegaMacro_PopupFrame = {}
MegaMacro_ButtonScrollFrame = {}
MegaMacro_CancelButton = {}
MegaMacro_FrameCharLimitText = {}
MegaMacro_PopupEditBox = {}
MegaMacro_EditButton = {}
MegaMacro_DeleteButton = {}
MegaMacro_FallbackTextureCheckBox = {}

C_ToyBox = {
    GetNumToys = function() end,
    GetNumFilteredToys = function() end,
    ForceToyRefilter = function() end,
    GetToyFromIndex = function(index) index._ = nil end,
    GetToyInfo = function(itemID) itemID._ = nil end
}