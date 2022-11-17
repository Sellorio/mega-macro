-- THIS FILE IS NOT PUBLISHED

-- This file is here to define WoW and UI globals that are not declared in code
-- so that syntax analysers can react favourably to it.

-- the `<value> and <variable>` syntax is used to allow the syntax analyser to
-- determine the data-type of the variable

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
GetSpellInfo = function(spellIdOrName) spellIdOrName._ = nil end -- returns: name, rank, icon, castTime, minRange, maxRange, spellId
GetSpellTexture = function(spellIdOrName, bookType) spellIdOrName._ = bookType end
GetItemInfoInstant = function(itemIdOrName) itemIdOrName._ = nil end -- returns: itemId, itemType, itemSubType, itemEquipLoc, icon, itemClassID, itemSubClassID
GetItemInfo = function(itemIdOrName) itemIdOrName._ = nil end -- returns: itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice
QueryCastSequence = function(sequence) sequence._ = nil end
GameTooltip_SetDefaultAnchor = function(tooltip, parent) tooltip._ = parent end
GetMouseFocus = function() end
message = function(text) text._ = nil end
InCombatLockdown = function() end
GetNumMacros = function() end -- returns: numglobal, numperchar
GetMacroBody = function(macroIndexOrName) macroIndexOrName._ = nil end
GetMacroInfo = function(macroIndexOrName) macroIndexOrName._ = nil end -- returns: name, iconTexture, body, isLocal
EditMacro = function(macroIndexOrName, name, icon, body, isLocal, perCharacter) end -- isLocal should always be passed in as true
DeleteMacro = function(macroIndexOrName) macroIndexOrName._ = nil end
CreateMacro = function(name, iconFileName, body, perCharacter) return 0 end
ActionButton_UpdateAction = function(self, force) self._ = force end
ActionButton_SetTooltip = function(self) self._ = nil end
GetActionInfo = function(actionId) actionId._ = nil end -- returns: spellType, id, subType
ActionButton_CalculateAction = function(self) self._ = nil end
PickupMacro = function(macroIndexOrName) macroIndexOrName._ = nil end
GetSpellCooldown = function(spellID) spellID._ = nil end -- returns: startTime, duration, enabled
GetItemCooldown = function(itemID) itemID._ = nil end -- returns: startTime, duration, enabled
GetSpellCharges = function(spellID) spellID._ = nil end -- returns: charges, maxCharges, chargeStart, chargeDuration, chargeModRate
GetItemCount = function(itemID, includeBank, includeCharges) itemID._ = nil end -- returns: count
GetSpellCount = function(spellID) spellID._ = nil end -- returns: count
IsCurrentSpell = function(spellID) spellID._ = nil end
IsCurrentItem = function(itemID) itemID._ = nil end
IsCurrentAction = function(action) action._ = nil end
GetShapeshiftForm = function(flag) flag._ = nil end
GetShapeshiftFormInfo = function(index) index._ = nil end -- returns: icon, active, castable, spellID
UnitBuff = function(unit, buffIndexOrName, filter) unit[buffIndexOrName] = filter end -- returns: name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId
IsUsableSpell = function(spellID) spellID._ = nil end -- returns: usable, noMana
IsUsableAction = function(action) action._ = nil end -- returns: usable, noMana
IsUsableItem = function(itemID) itemID._ = nil end -- returns: usable
IsActionInRange = function(action) action._ = nil end -- returns: inRange (boolean)
IsSpellInRange = function(index, bookType, target) bookType[index] = target end -- returns: inRange (boolean)
IsItemInRange = function(itemID, target) itemID._ = target end -- returns: inRange (boolean)
FindSpellBookSlotBySpellID = function(spellID) spellID._ = nil end -- returns: index
GetItemSpell = function(itemIdOrName) itemIdOrName._ = nil end -- returns: spellName, spellID
ShowMacroFrame = function() end
GetInventoryItemID = function(unit, slotId) unit._ = slotId end
GetMacroSpell = function(macroNameOrIndex) macroNameOrIndex._ = nil end -- returns: spellID
GetMacroIndexByName = function(macroName) macroName._ = nil end -- returns: macroIndex
GetActionCooldown = function(action) action._ = nil end -- returns: start, duration, enable
GetActionCount = function(action) action._ = nil end -- returns: count
GetActionTexture = function(action) action._ = nil end -- returns: texture
GetActionCharges = function(action) action._ = nil end -- returns: charges, maxCharges, chargeStart, chargeDuration, chargeModRate
IsEquippedAction = function(action) action._ = nil end -- returns: isEquipped
IsEquippedItem = function(itemID) itemID._ = nil end -- returns: isEquipped
IsEquippableItem = function(itemID) itemID._ = nil end -- returns: isEquippable
PutItemInBackpack = function() end
ClearCursor = function() end
GetCursorInfo = function() end -- returns: type, action1, action2, spellID
IsControlKeyDown = function() end
IsAltKeyDown = function() end
IsShiftKeyDown = function() end
PlaceAction = function(slot) slot._ = nil end
IsAutoRepeatAction = function(action) action._ = nil end -- returns: isRepeating
IsAutoRepeatSpell = function(spellId) spellId._ = nil end -- returns: isRepeating
GetSpellLossOfControlCooldown = function(spellID) spellID._ = nil end -- returns: start, duration
IsConsumableItem = function(itemID) itemID._ = nil end -- returns: isConsumable
IsConsumableSpell = function(itemID) itemID._ = nil end -- returns: isConsumable
C_LevelLink = {
    IsSpellLocked = function(spellID) spellID._ = nil end -- returns: isLocked
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