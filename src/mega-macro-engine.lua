local ClickyFrameName = "MegaMacroClicky"

local MegaMacroClickyMap = {}
local MacroIndexCache = {} -- caches native macro indexes - these change based on macro name so they are not the id we'll use in the addon
local ClickyFramePool = {}
local NextFrameId = 1

local function TryImportGlobalMacros()
    return true
end

local function TryImportCharacterMacros()
    return true
end

local function SetupGlobalMacros()
    return
end

local function SetupCharacterMacros()
    return
end

local function AquireClicky()
    local clicky

    if ClickyFramePool[1] then
        return table.remove(ClickyFramePool)
    else
        local name = ClickyFrameName..NextFrameId
        NextFrameId = NextFrameId + 1

        clicky = CreateFrame("Button", name, nil, "SecureActionButtonTemplate")
        clicky.Name = name
        clicky:SetAttribute("type", "macro")
        clicky:SetAttribute("macrotext", "")
    end

    return clicky
end

local function ReleaseClicky(clicky)
    clicky:SetAttribute("macrotext", "")
    table.insert(ClickyFramePool, clicky)
end

local function CreateMacroButtonFrameForMacro(macro)
    local clicky = AquireClicky()
    MegaMacroClickyMap[macro.Id] = clicky
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
            MegaMacroGlobalData.Activated = true
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
    -- update macro display name and cached macro index
end

function MegaMacroEngine.OnMacroUpdated(macro)
    MegaMacroClickyMap[macro.Id]:SetAttribute("macrotext", macro.Code)
end

function MegaMacroEngine.OnMacroDeleted(macro)
    ReleaseClicky(MegaMacroClickyMap[macro.Id])
    MegaMacroClickyMap[macro.Id] = nil
end