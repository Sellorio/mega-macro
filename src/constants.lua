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