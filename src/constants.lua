MacroLimits = {
	-- limit: 120 non-character specific macro slots
	GlobalCount = 60,
	PerClassCount = 30,
	PerSpecializationCount = 30,
	-- limit: 18 character specific macro slots
	PerCharacterCount = 8,
	PerCharacterSpecializationCount = 10
}

MacroStartIndexes = {
	Global = 1,
	PerClass = 1 + MacroLimits.GlobalCount,
	PerSpecialization = 1 + MacroLimits.GlobalCount + MacroLimits.PerClassCount,
	PerCharacter = 1 + MacroLimits.GlobalCount + MacroLimits.PerClassCount + MacroLimits.PerSpecializationCount,
	PerCharacterSpecialization = 1 + MacroLimits.GlobalCount + MacroLimits.PerClassCount + MacroLimits.PerSpecializationCount + MacroLimits.PerCharacterCount
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