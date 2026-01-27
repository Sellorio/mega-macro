MacroLimits = {
	-- limit: 120 non-character specific macro slots
	GlobalCount = 60,
	PerClassCount = 30,
	PerSpecializationCount = 30,
	-- limit: 18 character specific macro slots
	PerCharacterCount = 30,
	PerCharacterSpecializationCount = 0,
	InactiveCount = 160,
	MaxGlobalMacros = 120,
	MaxCharacterMacros = 30
}

MacroIndexOffsets = {
	Global = 0,
	PerClass = MacroLimits.GlobalCount,
	PerSpecialization = MacroLimits.GlobalCount + MacroLimits.PerClassCount,
	PerCharacter = MacroLimits.GlobalCount + MacroLimits.PerClassCount + MacroLimits.PerSpecializationCount,
	PerCharacterSpecialization = MacroLimits.GlobalCount + MacroLimits.PerClassCount + MacroLimits.PerSpecializationCount + MacroLimits.PerCharacterCount,
	Inactive = MacroLimits.GlobalCount + MacroLimits.PerClassCount + MacroLimits.PerSpecializationCount + MacroLimits.PerCharacterCount + MacroLimits.PerCharacterSpecializationCount,
	NativeCharacterMacros = 120
}

MegaMacroScopes = {
    Global = "gg",
    Class = "gc",
    Specialization = "gs",
    Character = "ch",
    CharacterSpecialization = "cs"
}

PetActionTextures = {
	Attack = 132152,
	Assist = 524348,
	Passive = 132311,
	Defensive = 132110,
	Follow = 132328,
	MoveTo = 457329,
	Stay = 136106,
	Dismiss = 136095
}

MegaMacroTexture = 134400
MegaMacroActiveStanceTexture = 136116
MegaMacroCodeMaxLength = 1024 -- Increased for 12.0 internal storage
MegaMacroCodeMaxLengthForNative = 255 -- Hard limit for Blizzard UI sync
HighestMaxMacroCount = math.max(MacroLimits.GlobalCount, MacroLimits.PerClassCount, MacroLimits.PerSpecializationCount, MacroLimits.PerCharacterCount, MacroLimits.PerCharacterSpecializationCount)

MegaMacroInfoFunctions = {
	Spell = {
		GetCooldown = function(abilityId)
			local spellCooldownInfo = C_Spell.GetSpellCooldown(abilityId)
			if spellCooldownInfo then
				return spellCooldownInfo.startTime, spellCooldownInfo.duration, spellCooldownInfo.isEnabled, spellCooldownInfo.modRate
			end
		end,
		GetCount = C_Spell.GetSpellCastCount,
		GetCharges = function(spellId) 
			return C_Spell.GetSpellCharges(spellId) 
		end,
		IsUsable = C_Spell.IsSpellUsable,
		IsInRange = function(spellId, target)
			-- 12.0: IsSpellInRange now accepts SpellID or Name directly without needing the SpellBook index
			local result = C_Spell.IsSpellInRange(spellId, target)
			if result == nil then
				return nil
			else
				return result
			end
		end,
		IsCurrent = C_Spell.IsCurrentSpell,
		IsEquipped = function(_) return false end,
		IsAutoRepeat = C_Spell.IsAutoRepeatSpell,
		IsLocked = C_LevelLink.IsSpellLocked,
		GetLossOfControlCooldown = C_Spell.GetSpellLossOfControlCooldown,
		IsOverlayed = C_Spell.GetSpellOverlayed -- Updated for 12.0 namespace
	},
	Item = {
		GetCooldown = C_Item.GetItemCooldown,
		GetCount = function(itemId) return C_Item.GetItemCount(itemId, false, true) end,
		GetCharges = function(_) return 0, 0, -1, 0, 1 end, 
		IsUsable = function(itemId) return C_Item.IsUsableItem(itemId) end,
		IsInRange = function(itemId, target)
			return C_Item.IsItemInRange(itemId, target)
		end,
		IsCurrent = C_Item.IsCurrentItem,
		IsEquipped = function(itemId) return C_Item.IsEquippedItem(itemId) end,
		IsAutoRepeat = function(_) return false end,
		IsLocked = function(_) return false end,
		GetLossOfControlCooldown = function(_) return -1, 0 end,
		IsOverlayed = function(_) return false end
	},
	Fallback = {
		GetCooldown = function(_) return -1, 0, true end,
		GetCount = function(_) return 0 end,
		GetCharges = function(_) return 0, 0, -1, 0, 1 end,
		IsUsable = function(_) return false, false end,
		IsInRange = function(_, _) return nil end,
		IsCurrent = function(_) return false end,
		IsEquipped = function(_) return false end,
		IsAutoRepeat = function(_) return false end,
		IsLocked = function(_) return false end,
		GetLossOfControlCooldown = function(_) return -1, 0 end,
		IsOverlayed = function(_) return false end
   },
	Unknown = {
		GetCooldown = function(_) return -1, 0, true end,
		GetCount = function(_) return 0 end,
		GetCharges = function(_) return 0, 0, -1, 0, 1 end,
		IsUsable = function(_) return true, false end,
		IsInRange = function(_, _) return nil end,
		IsCurrent = function(_) return false end,
		IsEquipped = function(_) return false end,
		IsAutoRepeat = function(_) return false end,
		IsLocked = function(_) return false end,
		GetLossOfControlCooldown = function(_) return -1, 0 end,
		IsOverlayed = function(_) return false end
	}
}