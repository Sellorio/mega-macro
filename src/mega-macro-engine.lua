local ClickyFrameName = "MegaMacroClicky"
local MacroIndexCache = {} -- caches native macro indexes - these change based on macro name so they are not the id we'll use in the addon
local Initialized = false

local function GenerateIdPrefix(id)
    local result = "00"..id
    return "#"..string.sub(result, -3)
end

local function GetIdFromMacroCode(macroCode)
    return tonumber(string.sub(macroCode, 2, 4))
end

local function InitializeMacroIndexCache()
    MacroIndexCache = {}

    local maxMacroCount = MacroLimits.MaxGlobalMacros + MacroLimits.MaxCharacterMacros
    for i=1, maxMacroCount do
        local macroCode = GetMacroBody(i)
        local macroId = GetIdFromMacroCode(macroCode)
        MacroIndexCache[macroId] = i
    end
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
    local globalCount = GetNumMacros()

    for i=1, globalCount do
        EditMacro(i, nil, nil, GenerateIdPrefix(i).."\n".."/click "..ClickyFrameName..i, true, false)
    end

    for i=1 + globalCount, MacroLimits.MaxGlobalMacros do
        CreateMacro(" ", MegaMacroTexture, GenerateIdPrefix(i).."\n".."/click "..ClickyFrameName..i, false)
    end
end

local function SetupCharacterMacros()
    local _, characterCount = GetNumMacros()

    for i=1, characterCount do
        local id = MacroLimits.MaxGlobalMacros + i
        EditMacro(id, nil, nil, GenerateIdPrefix(id).."\n".."/click "..ClickyFrameName..id, true, true)
    end

    for i=1 + characterCount, MacroLimits.MaxCharacterMacros do
        local id = MacroLimits.MaxGlobalMacros + i
        CreateMacro(" ", MegaMacroTexture, GenerateIdPrefix(id).."\n".."/click "..ClickyFrameName..id, true)
    end
end

local function GetOrCreateClicky(macroId)
    local name = ClickyFrameName..macroId
    local clicky = _G[name]

    if not clicky then
        clicky = CreateFrame("Button", name, nil, "SecureActionButtonTemplate")
        clicky:SetAttribute("type", "macro")
        clicky:SetAttribute("macrotext", "")
    end

    return clicky
end

local function BindMacro(macro)
    if Initialized then
        local macroIndex = MacroIndexCache[macro.Id]
        local isCharacter = macroIndex > MacroLimits.MaxGlobalMacros

        if not isCharacter and MegaMacroGlobalData.Activated or isCharacter and MegaMacroCharacterData.Activated then
            GetOrCreateClicky(macro.Id):SetAttribute("macrotext", macro.Code)
            EditMacro(macroIndex, macro.DisplayName, nil, nil, true, isCharacter)
            InitializeMacroIndexCache()
        end
    end
end

local function UnbindMacro(macro)
    if Initialized then
        local macroIndex = MacroIndexCache[macro.Id]
        local isCharacter = macroIndex > MacroLimits.MaxGlobalMacros

        if not isCharacter and MegaMacroGlobalData.Activated or isCharacter and MegaMacroCharacterData.Activated then
            GetOrCreateClicky(macro.Id):SetAttribute("macrotext", "")
            EditMacro(macroIndex, " ", nil, nil, true, isCharacter)
            InitializeMacroIndexCache()
        end
    end
end

local function BindMacrosList(macroList)
    local count = #macroList
    for i=1, count do
        BindMacro(macroList[i])
    end
end

local function UnbindMacrosList(macroList)
    local count = #macroList
    for i=1, count do
        UnbindMacro(macroList[i])
    end
end

local function BindMacros()
    BindMacrosList(MegaMacroGlobalData.Macros)

    if MegaMacroGlobalData.Classes[MegaMacroCachedClass] then
        BindMacrosList(MegaMacroGlobalData.Classes[MegaMacroCachedClass].Macros)

        if MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization] then
            BindMacrosList(MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization].Macros)
        end
    end

    BindMacrosList(MegaMacroCharacterData.Macros)

    if MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization] then
        BindMacrosList(MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization].Macros)
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

    InitializeMacroIndexCache()
    Initialized = true

    BindMacros()

    return true
end

function MegaMacroEngine.OnMacroCreated(macro)
    BindMacro(macro)
end

function MegaMacroEngine.OnMacroRenamed(macro)
    BindMacro(macro)
end

function MegaMacroEngine.OnMacroUpdated(macro)
    BindMacro(macro)
end

function MegaMacroEngine.OnMacroDeleted(macro)
    UnbindMacro(macro)
end

function MegaMacroEngine.OnSpecializationChanged(oldValue, newValue)
    UnbindMacrosList(MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[oldValue].Macros)
    UnbindMacrosList(MegaMacroCharacterData.Specializations[oldValue].Macros)

    BindMacrosList(MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[newValue].Macros)
    BindMacrosList(MegaMacroCharacterData.Specializations[newValue].Macros)
end