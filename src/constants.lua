MacroLimits = {
	-- limit: 120 non-character specific macro slots
	GlobalCount = 60,
	PerClassCount = 30,
	PerSpecializationCount = 30,
	-- limit: 18 character specific macro slots
	PerCharacterCount = 8,
	PerCharacterSpecializationCount = 10
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

MegaMacroCodeMaxLength = 1023
HighestMaxMacroCount = math.max(MacroLimits.GlobalCount, MacroLimits.PerClassCount, MacroLimits.PerSpecializationCount, MacroLimits.PerCharacterCount, MacroLimits.PerCharacterSpecializationCount)