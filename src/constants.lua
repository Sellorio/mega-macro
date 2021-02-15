MacroLimits = {
	-- limit: 120 non-character specific macro slots
	GlobalCount = 60,
	PerClassCount = 30,
	PerSpecializationCount = 30,
	-- limit: 18 character specific macro slots
	PerCharacterCount = 8,
	PerCharacterSpecializationCount = 10,
	MaxGlobalMacros = 120,
	MaxCharacterMacros = 18
}

MacroIndexOffsets = {
	Global = 0,
	PerClass = MacroLimits.GlobalCount,
	PerSpecialization = MacroLimits.GlobalCount + MacroLimits.PerClassCount,
	PerCharacter = MacroLimits.GlobalCount + MacroLimits.PerClassCount + MacroLimits.PerSpecializationCount,
	PerCharacterSpecialization = MacroLimits.GlobalCount + MacroLimits.PerClassCount + MacroLimits.PerSpecializationCount + MacroLimits.PerCharacterCount,
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
MegaMacroCodeMaxLength = 1023
HighestMaxMacroCount = math.max(MacroLimits.GlobalCount, MacroLimits.PerClassCount, MacroLimits.PerSpecializationCount, MacroLimits.PerCharacterCount, MacroLimits.PerCharacterSpecializationCount)

MegaMacroInfoFunctions = {
	Spell = {
		GetCooldown = GetSpellCooldown,
		GetCount = GetSpellCount,
		GetCharges = function(spellId) return GetSpellCharges(spellId) end,
		IsUsable = IsUsableSpell,
		IsInRange = function(spellId, target)
			local spellIndex = FindSpellBookSlotBySpellID(spellId)
			if spellIndex then
				local result = IsSpellInRange(spellIndex, "spell", target)

				if result == nil then
					return nil
				else
					return result ~= 0
				end
            end
		end,
		IsCurrent = IsCurrentSpell,
		IsEquipped = function(_) return false end,
		IsAutoRepeat = IsAutoRepeatSpell,
		IsLocked = C_LevelLink.IsSpellLocked,
		GetLossOfControlCooldown = GetSpellLossOfControlCooldown,
		IsOverlayed = IsSpellOverlayed
	},
 	Item = {
		GetCooldown = GetItemCooldown,
		GetCount = function(itemId) return GetItemCount(itemId, false, true) end,
		GetCharges = function(_) return 0, 0, -1, 0, 1 end, -- charges, maxCharges, chargeStart, chargeDuration, chargeModRate
		IsUsable = function(itemId) return IsUsableItem(itemId), false end,
		IsInRange = IsItemInRange,
		IsCurrent = IsCurrentItem,
		IsEquipped = function(itemId) return IsEquippedItem(itemId) end,
		IsAutoRepeat = function(_) return false end,
		IsLocked = function(_) return false end,
		GetLossOfControlCooldown = function(_) return -1, 0 end,
		IsOverlayed = function(_) return false end
	},
	Fallback = {
		GetCooldown = function(_) return -1, 0, true end,
		GetCount = function(_) return 0 end,
		GetCharges = function(_) return 0, 0, -1, 0, 1 end, -- charges, maxCharges, chargeStart, chargeDuration, chargeModRate
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
		GetCharges = function(_) return 0, 0, -1, 0, 1 end, -- charges, maxCharges, chargeStart, chargeDuration, chargeModRate
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