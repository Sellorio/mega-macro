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
MegaMacro_RenameButton = {}
MegaMacro_DeleteButton = {}

C_ToyBox = {
    GetNumToys = function() end,
    GetNumFilteredToys = function() end,
    ForceToyRefilter = function() end,
    GetToyFromIndex = function(index) index._ = nil end,
    GetToyInfo = function(itemID) itemID._ = nil end
}