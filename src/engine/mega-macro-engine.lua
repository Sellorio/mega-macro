local ClickyFrameName = "MegaMacroClicky"
local MacroIndexCache = {} -- caches native macro indexes - these change based on macro name so they are not the id we'll use in the addon
local Initialized = false

local function GenerateIdPrefix(id)
    local result = "00"..id
    return "#"..string.sub(result, -3)
end

local function FormatMacroDisplayName(megaMacroDisplayName)
    if not megaMacroDisplayName or #megaMacroDisplayName == 0 then
        return " "
    else
        return string.sub(megaMacroDisplayName, 1, 18)
    end
end

local function GetIdFromMacroCode(macroCode)
    return macroCode and tonumber(string.sub(macroCode, 2, 4))
end

local function InitializeMacroIndexCache()
    MacroIndexCache = {}

    if MegaMacroGlobalData.Activated then
        for i=1, MacroLimits.MaxGlobalMacros do
            local macroCode = GetMacroBody(i)

            if macroCode then
                local macroId = GetIdFromMacroCode(macroCode)

                if macroId then
                    MacroIndexCache[macroId] = i
                end
            end
        end
    end

    if MegaMacroCharacterData.Activated then
        for i=1 + MacroLimits.MaxGlobalMacros, MacroLimits.MaxGlobalMacros + MacroLimits.MaxCharacterMacros do
            local macroCode = GetMacroBody(i)

            if macroCode then
                local macroId = GetIdFromMacroCode(macroCode)

                if macroId then
                    MacroIndexCache[macroId] = i
                end
            end
        end
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
        local macro = MegaMacro.Create(name, MegaMacroScopes.Global, MegaMacroTexture)

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
        local macro = MegaMacro.Create(name, MegaMacroScopes.Character, MegaMacroTexture)

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

local function GetMacroStubCode(macroId)
    -- Fix a bug that causes click events not to register only when CVar ActionButtonUseKeyDown is set to 1. 
    local keyDownOrUp = GetCVar("ActionButtonUseKeyDown")
    local primaryMacroButtonClickValue = keyDownOrUp == "1" and " LeftButton" or ""
    return
        GenerateIdPrefix(macroId).."\n"..
        "/click [btn:1] "..ClickyFrameName..macroId..primaryMacroButtonClickValue.." "..keyDownOrUp.."\n"..
        "/click [btn:2] "..ClickyFrameName..macroId.." RightButton "..keyDownOrUp.."\n"..
        "/click [btn:3] "..ClickyFrameName..macroId.." MiddleButton "..keyDownOrUp.."\n"..
        "/click [btn:4] "..ClickyFrameName..macroId.." Button4 "..keyDownOrUp.."\n"..
        "/click [btn:5] "..ClickyFrameName..macroId.." Button5 "..keyDownOrUp.."\n"
end

local function SetupGlobalMacros()
    local globalCount = GetNumMacros()

    for i=1, globalCount do
        EditMacro(i, nil, nil, GenerateIdPrefix(i).."\n", true, false)
    end
end

local function SetupCharacterMacros()
    local _, characterCount = GetNumMacros()

    for i=1, characterCount do
        local id = MacroLimits.MaxGlobalMacros + i
        EditMacro(id, nil, nil, GenerateIdPrefix(id).."\n", true, true)
    end
end

local function SetupOrUpdateMacros()
    if not InCombatLockdown() then
        local globalCount, characterCount = GetNumMacros()

        if MegaMacroGlobalData.Activated and globalCount < MacroLimits.MaxGlobalMacros then
            for _=1, MacroLimits.MaxGlobalMacros - globalCount do
                CreateMacro(" ", MegaMacroTexture, "", false)
            end
        end

        if MegaMacroCharacterData.Activated and characterCount < MacroLimits.MaxCharacterMacros then
            for _=1, MacroLimits.MaxCharacterMacros - characterCount do
                CreateMacro(" ", MegaMacroTexture, "", true)
            end
        end

        local assignedMacroIds = {}
        local unassignedMacros = {}

        -- skip global macros if they are not activated
        local startIndex = MegaMacroGlobalData.Activated and 1 or MacroLimits.MaxGlobalMacros + 1
        -- stop before character macros if they are not activated
        local endIndex = MegaMacroCharacterData.Activated and MacroLimits.MaxGlobalMacros + MacroLimits.MaxCharacterMacros or MacroLimits.MaxGlobalMacros

        for i=startIndex, endIndex do
            local code = GetMacroBody(i)
            local macroId = GetIdFromMacroCode(code)

            if macroId then
                local isCharacterSpecificMacroId = macroId > MacroLimits.MaxGlobalMacros
                local isCharacterSpecificMacroIndex = i > MacroLimits.MaxGlobalMacros

                if assignedMacroIds[macroId] or isCharacterSpecificMacroId ~= isCharacterSpecificMacroIndex then
                    table.insert(unassignedMacros, i)
                else
                    assignedMacroIds[macroId] = i
                    EditMacro(i, nil, MegaMacroTexture, GetMacroStubCode(macroId), true, isCharacterSpecificMacroIndex)
                end
            else
                table.insert(unassignedMacros, i)
            end
        end

        local lastCheckedMacroId = startIndex - 1
        for _, macroIndex in ipairs(unassignedMacros) do
            while lastCheckedMacroId < endIndex do
                lastCheckedMacroId = lastCheckedMacroId + 1
                if not assignedMacroIds[lastCheckedMacroId] then
                    EditMacro(macroIndex, nil, nil, GetMacroStubCode(lastCheckedMacroId), true, macroIndex > MacroLimits.MaxGlobalMacros)
                    break
                end
            end
        end
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

        if macroIndex then
            GetOrCreateClicky(macro.Id):SetAttribute("macrotext", macro.Code)
            EditMacro(macroIndex, FormatMacroDisplayName(macro.DisplayName), nil, nil, true, macroIndex > MacroLimits.MaxGlobalMacros)
            InitializeMacroIndexCache()
        end
    end
end

local function UnbindMacro(macro)
    if Initialized then
        local macroIndex = MacroIndexCache[macro.Id]

        if macroIndex then
            GetOrCreateClicky(macro.Id):SetAttribute("macrotext", "")
            EditMacro(macroIndex, " ", nil, nil, true, macroIndex > MacroLimits.MaxGlobalMacros)
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

local function PickupMacroWrapper(original, macroIndex)
    if InCombatLockdown() then
        return
    end

    local macroId = macroIndex and MegaMacroEngine.GetMacroIdFromIndex(macroIndex)

    if macroId then
        local data = MegaMacroIconEvaluator.GetCachedData(macroId)
        EditMacro(macroIndex, nil, data and data.Icon, nil, true, macroIndex > MacroLimits.MaxGlobalMacros)
    end

    original(macroIndex)

    -- revert icon so that if a macro is dragged during combat, it will show the blank icon instead of an out-of-date macro icon
    if macroId then
        EditMacro(macroIndex, nil, MegaMacroTexture, nil, true, macroIndex > MacroLimits.MaxGlobalMacros)
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
        end
    end

    -- Ensures the macro code is the latest version. it was required to change macro stub code in 1.2. this will also allow for future changes.
    SetupOrUpdateMacros()
    InitializeMacroIndexCache()
    Initialized = true

    BindMacros()

    local originalPickupMacro = PickupMacro
    PickupMacro = function(macroIndex) PickupMacroWrapper(originalPickupMacro, macroIndex) end

    return true
end

function MegaMacroEngine.Reinitialize()

end

function MegaMacroEngine.GetMacroIdFromIndex(macroIndex)
    for id, index in pairs(MacroIndexCache) do
        if index == macroIndex then
            return id
        end
    end

    return nil
end

function MegaMacroEngine.GetMacroIndexFromId(macroId)
    return MacroIndexCache[macroId]
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
    -- unbind the macro from any action bar slots its bound to
    if not InCombatLockdown() then
        for i=1, 120 do
            local type, id = GetActionInfo(i)
            if type == "macro" and MegaMacroEngine.GetMacroIdFromIndex(id) == macro.Id then
                PickupAction(i)
                ClearCursor()
            end
        end
    end

    UnbindMacro(macro)
end

function MegaMacroEngine.OnMacroMoved(oldMacro, newMacro)
    -- update binding from old macro to new macro (move is actually a create+delete)
    if not InCombatLockdown() then
        for i=1, 120 do
            local type, id = GetActionInfo(i)
            if type == "macro" and MegaMacroEngine.GetMacroIdFromIndex(id) == oldMacro.Id then
                PickupMacro(MacroIndexCache[newMacro.Id])
                PlaceAction(i)
                ClearCursor()
            end
        end
    end
end

function MegaMacroEngine.OnSpecializationChanged(oldValue, newValue)
    UnbindMacrosList(MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[oldValue].Macros)
    UnbindMacrosList(MegaMacroCharacterData.Specializations[oldValue].Macros)

    BindMacrosList(MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[newValue].Macros)
    BindMacrosList(MegaMacroCharacterData.Specializations[newValue].Macros)
end