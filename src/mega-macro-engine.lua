local ClickyFrameName = "MegaMacroClicky"
local MacroIndexCache = {} -- caches native macro indexes - these change based on macro name so they are not the id we'll use in the addon

local function GenerateIdPrefix(id)
    local result = "00"..id
    return "#"..string.sub(result, -3)
end

local function GetIdFromMacroCode(macroCode)
    return tonumber(string.sub(macroCode, 2, 4))
end

local function TryImportGlobalMacros()
    local numberOfGlobalMacros = GetNumMacros()
    local globalMegaMacros = MegaMacro.GetMacrosInScope(MegaMacroScopes.Global)

    if numberOfGlobalMacros + #globalMegaMacros > MacroLimits.GlobalCount then
        return
            false,
            "Mega Macro: There isn't enough space to import your existing global macros. The limit "..
            "for global macros when using Mega Macro is "..MacroLimits.GlobalCount.." to make room for per-class and per-spec macro slots. "..
            "Please use /reload once you have manually copied over/sorted the macros."
    end

    for i=1, #globalMegaMacros do
        globalMegaMacros[i].Id = i + numberOfGlobalMacros + MacroIndexOffsets.Global
    end

    for i=1, numberOfGlobalMacros do
        local name, _, body, _ = GetMacroInfo(i)
        local macro = MegaMacro.Create(name, MegaMacroScopes.Global)

        if macro == nil then
            return
                false,
                "Mega Macro: Failed to import all global macros. This is likely due to not having enough macro slots available. "..
                "Please use /reload once you have manually copied over/sorted the macros."
        end

        MegaMacro.UpdateCode(macro, body)
    end

    return true
end

local function TryImportCharacterMacros()
    local _, numberOfCharacterMacros = GetNumMacros()
    local characterMegaMacros = MegaMacro.GetMacrosInScope(MegaMacroScopes.Character)

    if numberOfCharacterMacros + #characterMegaMacros > MacroLimits.PerCharacterCount then
        return
            false,
            "Mega Macro: There isn't enough space to import your existing character-specific macros. The limit "..
            "for character macros when using Mega Macro is "..MacroLimits.PerCharacterCount.." to make room for per-character per-spec macro slots. "..
            "Please use /reload once you have manually copied over/sorted the macros."
    end

    for i=1, #characterMegaMacros do
        characterMegaMacros[i].Id = i + numberOfCharacterMacros + MacroIndexOffsets.NativeCharacterMacros
    end

    for i=1, numberOfCharacterMacros do
        local name, _, body, _ = GetMacroInfo(i + MacroIndexOffsets.NativeCharacterMacros)
        local macro = MegaMacro.Create(name, MegaMacroScopes.Character)

        if macro == nil then
            return
                false,
                "Mega Macro: Failed to import all character macros. This is likely due to not having enough macro slots available. "..
                "Please use /reload once you have manually copied over/sorted the macros."
        end

        MegaMacro.UpdateCode(macro, body)
    end

    return true
end

local function SetupGlobalMacros()
    -- existing macros are updated to be blank but with the id as their current index, display name is not changed
    -- existing macro display names are blanked now after all ids are set
    -- new macros are added to fill all available slots and have their ids set
    return
end

local function SetupCharacterMacros()
    -- existing macros are updated to be blank but with the id as their current index, display name is not changed
    -- existing macro display names are blanked now after all ids are set
    -- new macros are added to fill all available slots and have their ids set
    return
end

local function GetOrCreateClicky(macroId)
    local name = ClickyFrameName..macroId
    local clicky = _G[name]

    if not clicky then
        clicky = CreateFrame("Button", name, nil, "SecureActionButtonTemplate")
        clicky.Name = name
        clicky:SetAttribute("type", "macro")
        clicky:SetAttribute("macrotext", "")
    end

    return clicky
end

local function CreateMacroButtonFrameForMacro(macro)
    local clicky = GetOrCreateClicky(macro.Id)
    clicky:SetAttribute("macrotext", macro.Code)
end

local function CreateMacroButtonFramesForList(macroList)
    local length = #macroList
    for i=1, length do
        CreateMacroButtonFrameForMacro(macroList[i])
    end
end

local function CreateMacroClickies()
    CreateMacroButtonFramesForList(MegaMacroGlobalData.Macros)

    if MegaMacroGlobalData.Classes[MegaMacroCachedClass] then
        CreateMacroButtonFramesForList(MegaMacroGlobalData.Classes[MegaMacroCachedClass].Macros)

        if MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization] then
            CreateMacroButtonFramesForList(MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization].Macros)
        end
    end

    CreateMacroButtonFramesForList(MegaMacroCharacterData.Macros)

    if MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization] then
        CreateMacroButtonFramesForList(MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization].Macros)
    end
end

MegaMacroEngine = {}

function MegaMacroEngine.SafeInitialize()
    local inCombat = InCombatLockdown()

    if not MegaMacroGlobalData.Activated then
        if inCombat then
            return false
        end

        local importSuccessful, errorMessage = TryImportGlobalMacros()

        if importSuccessful then
            SetupGlobalMacros()
            MegaMacroGlobalData.Activated = true
        else
            message(errorMessage)
            return false
        end
    end

    if not MegaMacroCharacterData.Activated then
        if inCombat then
            return false
        end

        local importSuccessful, errorMessage = TryImportCharacterMacros()

        if importSuccessful then
            SetupCharacterMacros()
            MegaMacroCharacterData.Activated = true
        else
            message(errorMessage)
            return false
        end
    end

    CreateMacroClickies()

    return true
end

function MegaMacroEngine.OnMacroCreated(macro)
    CreateMacroButtonFrameForMacro(macro)
end

function MegaMacroEngine.OnMacroRenamed(macro)
    -- update macro display name and cached macro indexes
end

function MegaMacroEngine.OnMacroUpdated(macro)
    GetOrCreateClicky(macro.Id):SetAttribute("macrotext", macro.Code)
end

function MegaMacroEngine.OnMacroDeleted(macro)
    GetOrCreateClicky(macro.Id):SetAttribute("macrotext", "")
end