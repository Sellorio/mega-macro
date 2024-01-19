MegaMacroEngine = {}
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

    for i=1, MacroLimits.MaxGlobalMacros do
        local macroCode = GetMacroBody(i)

        if macroCode then
            local macroId = GetIdFromMacroCode(macroCode)

            if macroId then
                MacroIndexCache[macroId] = i
            end
        end
    end

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

local function GenerateNativeMacroCode(macro)
    -- Check if there is #showtooltip already. If not, add it to the start.
    local code = macro.Code
    if #code <= MegaMacroCodeMaxLengthForNative - 14 then
        if not string.find(code, "#showtooltip") then
            code = "#showtooltip\n" .. code
        end
    end
    code = GenerateIdPrefix(macro.Id) .. "\n" .. code
    return code
end

local function getTexture(macro, macroIndex)
    local macroIndex = macroIndex or MacroIndexCache[macro.Id]
    local iconTexture = macro.StaticTexture
    if macroIndex and not iconTexture then
        local _, iconTexture = GetMacroInfo(macroIndex)
    end
    return iconTexture
end

local function BindMacro(macro, macroIndex)
    local macroIndex = macroIndex or MacroIndexCache[macro.Id]

    -- Bind code to macro
    if macroIndex then
        local iconTexture = getTexture(macro, macroIndex)
        if #macro.Code <= MegaMacroCodeMaxLengthForNative then
            EditMacro(macroIndex, FormatMacroDisplayName(macro.DisplayName), iconTexture, GenerateNativeMacroCode(macro), true, macroIndex > MacroLimits.MaxGlobalMacros)
        else
            MegaMacroEngine.GetOrCreateClicky(macro.Id):SetAttribute("macrotext", macro.Code)
            EditMacro(macroIndex, FormatMacroDisplayName(macro.DisplayName), iconTexture, MegaMacroEngine.GetMacroStubCode(macro.Id), true, macroIndex > MacroLimits.MaxGlobalMacros)
        end
        InitializeMacroIndexCache()
    end
end

local function BindNewMacro(macro, macroIndex)
    local macroIndex = macroIndex or MacroIndexCache[macro.Id]

    if not macroIndex then
        -- Find a free slot. Need to know if global or character
        local isGlobal = macro.Scope == MegaMacroScopes.Global or macro.Scope == MegaMacroScopes.Class or macro.Scope == MegaMacroScopes.Specialization
        macroIndex = isGlobal and MegaMacroEngine.FindAvailableGlobalMacro() or MegaMacroEngine.FindAvailableCharacterMacro()
    end
    -- Bind code to macro
    BindMacro(macro, macroIndex)
end

local function TryImportGlobalMacros()
    local numberOfGlobalMacros = GetNumMacros()

    for i=1, numberOfGlobalMacros do
        local name, iconTexture, body, _ = GetMacroInfo(i)
        -- First, is it already a Mega Macro?
        local macroId = GetIdFromMacroCode(body)
        
        if not macroId then
            local macro = MegaMacro.Create(name, MegaMacroScopes.Global, iconTexture or MegaMacroTexture, true, body, i)

            if macro == nil then
                macro = MegaMacro.Create(name, MegaMacroScopes.Inactive, iconTexture or MegaMacroTexture, true, body, i)
                if macro == nil then
                    return false, "Failed to import at macro " .. i .. "(" .. name .. "). Please delete the macro and reload your UI."
                end
                -- print("Importing Inactive Global macro " .. i  .. " ".. name .. " to " ..  " #" .. macro.Id)
            end
        end
    end
    local newNumberOfGlobalMacros = GetNumMacros()
    if newNumberOfGlobalMacros > numberOfGlobalMacros then
        print("Mega Macro: Global import created " .. newNumberOfGlobalMacros - numberOfGlobalMacros .. " macros.")
    end

    return true
end

local function TryImportCharacterMacros()
    local _, numberOfCharacterMacros = GetNumMacros()

    for i=1 + MacroIndexOffsets.NativeCharacterMacros, numberOfCharacterMacros + MacroIndexOffsets.NativeCharacterMacros do
        local name, iconTexture, body, _ = GetMacroInfo(i)
        -- First, is it already a Mega Macro?
        local macroId = GetIdFromMacroCode(body)

        if not macroId then
            local macro = MegaMacro.Create(name, MegaMacroScopes.Character, iconTexture or MegaMacroTexture, true, body, i)

            if macro == nil then
                macro = MegaMacro.Create(name, MegaMacroScopes.Inactive, iconTexture or MegaMacroTexture, true, body, i)
                if macro == nil then
                    return false, "Failed to import at macro " .. i .. "(" .. name .. "). Please delete the macro and reload your UI."
                end
                -- print("Importing Inactive Char macro " .. i  .. " ".. name .. " to " ..  " #" .. macro.Id)
            end
        end
    end
    local _, newNumberOfCharacterMacros = GetNumMacros()
    if newNumberOfCharacterMacros > numberOfCharacterMacros then
        print("Mega Macro: Character import created " .. newNumberOfCharacterMacros - numberOfCharacterMacros .. " macros.")
    end

    return true
end

local function MergeCharacterSpecializationMacros()
    -- Remove the character specialization macros and add them to character macros.
    local characterSpecializationMacros = MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization].Macros
    local characterMacros = MegaMacroCharacterData.Macros
    if not characterSpecializationMacros or #characterSpecializationMacros == 0 then
        return
    end
    for i=1, #characterSpecializationMacros do
        -- if we don't have room, move to inactive
        if #characterMacros >= MacroLimits.MaxCharacterMacros then
            local macro = characterSpecializationMacros[i]
            macro.Scope = MegaMacroScopes.Inactive
            macro.Id = MegaMacro.GetNextAvailableMacroId(MacroIndexOffsets.Inactive, MacroLimits.InactiveCount, MegaMacroGlobalData.InactiveMacros)
            table.insert(MegaMacroGlobalData.InactiveMacros, macro)
        else 
            local macro = characterSpecializationMacros[i]
            macro.Scope = MegaMacroScopes.Character
            macro.Id = MegaMacro.GetNextAvailableMacroId(MacroIndexOffsets.NativeCharacterMacros, MacroLimits.MaxCharacterMacros, MegaMacroCharacterData.Macros)
            table.insert(characterMacros, macro)
        end
    end
    MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization].Macros = {}
end


function MegaMacroEngine.GetMacroStubCode(macroId)
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

function MegaMacroEngine.FindAvailableGlobalMacro()
    if not InCombatLockdown() then
        local globalCount, characterCount = GetNumMacros()

        -- Find used indexes from MacroIndexCache
        local usedMacroIndexes = {}
        for _, index in pairs(MacroIndexCache) do
            usedMacroIndexes[index] = true
        end

        local startIndex = 1
        local endIndex = MacroLimits.MaxGlobalMacros

        -- If there is a free slot, use that first.
        local hasFreeSlot = globalCount < MacroLimits.MaxGlobalMacros
        if hasFreeSlot then
            return CreateMacro(" ", MegaMacroTexture, " ", false)
        end

        for i=startIndex, endIndex do
            if not usedMacroIndexes[i] then
                return i
            end
        end
        -- Didn't find a free slot. Try to find an inactive one.
        for i=startIndex, endIndex do
            if usedMacroIndexes[i] and MegaMacroEngine.GetMacroIdFromIndex(i) > MacroIndexOffsets.Inactive then
                return i
            end
        end
        print("Mega Macro: Failed to find available global macro slot.")
        return nil
    end
end

function MegaMacroEngine.FindAvailableCharacterMacro()
    if not InCombatLockdown() then
        local globalCount, characterCount = GetNumMacros()

        -- Find used indexes from MacroIndexCache
        local usedMacroIndexes = {}
        for _, index in pairs(MacroIndexCache) do
            usedMacroIndexes[index] = true
        end

        local startIndex = 1 + MacroIndexOffsets.NativeCharacterMacros
        local endIndex = MacroLimits.MaxGlobalMacros + MacroLimits.MaxCharacterMacros

        -- If there is a free slot, use that first. Otherwise, return the first one that isn't indexed.
        local hasFreeSlot = characterCount < MacroLimits.MaxCharacterMacros
        if hasFreeSlot then
            local index = CreateMacro(" ", MegaMacroTexture, " ", true)
            -- print("Mega Macro: Created new character macro at index " .. index .. ".")
            return index
        end
        
        for i=startIndex, endIndex do
            if not usedMacroIndexes[i] then
                return i
            end
        end

        return nil
    end
end

function MegaMacroEngine.GetOrCreateClicky(macroId)
    local name = ClickyFrameName..macroId
    local clicky = _G[name]

    if not clicky then
        clicky = CreateFrame("Button", name, nil, "SecureActionButtonTemplate")
        clicky:SetAttribute("type", "macro")
        clicky:SetAttribute("macrotext", "")
    end

    return clicky
end

local function UnbindMacro(macro)
    if Initialized then
        local macroIndex = MacroIndexCache[macro.Id]

        if macroIndex then
            MegaMacroEngine.GetOrCreateClicky(macro.Id):SetAttribute("macrotext", "")
            EditMacro(macroIndex, " ", nil, GenerateIdPrefix(macro.Id), true, macroIndex > MacroLimits.MaxGlobalMacros)
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
    if MegaMacroConfig['UseNativeActionBar'] then
        original(macroIndex)
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



function MegaMacroEngine.SafeInitialize()
    if InCombatLockdown() then
        return false
    end

    MergeCharacterSpecializationMacros()

    InitializeMacroIndexCache()
    Initialized = true

    BindMacros() 

    local originalPickupMacro = PickupMacro
    PickupMacro = function(macroIndex) PickupMacroWrapper(originalPickupMacro, macroIndex) end

    return true
end

function MegaMacroEngine.VerifyMacros()
    -- Verify all is well. Check for macros in wrong space, or duplicate macros.
    local numberOfGlobalMacros, numberOfCharacterMacros = GetNumMacros()

    for i=1, numberOfGlobalMacros do
        local name, _, body, _ = GetMacroInfo(i)
        local macroId = GetIdFromMacroCode(body)
        
        if macroId then
            if macroId > MacroLimits.MaxGlobalMacros and macroId < MacroIndexOffsets.Inactive then
                print("Mega Macro: Found character macro in global space! " .. i .. " " .. name .. " #" .. macroId)
                DeleteMacro(i)
            end
        end
    end


    for i=1 + MacroIndexOffsets.NativeCharacterMacros, numberOfCharacterMacros + MacroIndexOffsets.NativeCharacterMacros do
        local name, _, body, _ = GetMacroInfo(i)
        local macroId = GetIdFromMacroCode(body)
        
        if macroId then
            if macroId < MacroIndexOffsets.NativeCharacterMacros then
                print("Mega Macro: Found global macro in character space! " .. i .. " " .. name .. " #" .. macroId)
                DeleteMacro(i)
            end
        end
    end

    InitializeMacroIndexCache()
    -- Verify that every macro in the addon is in the macro index cache. If not, we need to make a new macro. Also check duplicates
    local macroIds = {}
    local function VerifyMacro(macro, i)
        local macroId = macro.Id
        local macroIndex = MacroIndexCache[macro.Id]
        -- Check for duplicate macroIds
        if macroIds[macroId] then
            -- print("Mega Macro: Found duplicate macroId " .. macroId .. " " .. macro.DisplayName)
        else
            macroIds[macroId] = true
        end
        -- Check for missing macroIndex
        if not macroIndex then
            print("Mega Macro: Fixing missing macro " .. macro.Id .. " " .. macro.DisplayName)
            BindNewMacro(macro)
        end

        return true
    end

    for i=1, #MegaMacroGlobalData.Macros do
        VerifyMacro(MegaMacroGlobalData.Macros[i], i)
    end

    for i=1, #MegaMacroCharacterData.Macros do
        VerifyMacro(MegaMacroCharacterData.Macros[i], i)
    end

    if MegaMacroGlobalData.Classes[MegaMacroCachedClass] then
        for i=1, #MegaMacroGlobalData.Classes[MegaMacroCachedClass].Macros do
            VerifyMacro(MegaMacroGlobalData.Classes[MegaMacroCachedClass].Macros[i], i)
        end

        if MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization] then
            for i=1, #MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization].Macros do
                VerifyMacro(MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization].Macros[i], i)
            end
        end
    end

    InitializeMacroIndexCache()
    
end

function MegaMacroEngine.ImportMacros()
    if InCombatLockdown() then
        return false
    end

    local importSuccessful, errorMessage = TryImportGlobalMacros()
    if importSuccessful then
        MegaMacroGlobalData.Activated = true
    else
        message(errorMessage)
    end

    local importSuccessful, errorMessage = TryImportCharacterMacros()
    if importSuccessful then
        MegaMacroCharacterData.Activated = true
    else
        message(errorMessage)
    end

    InitializeMacroIndexCache()
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

function MegaMacroEngine.OnMacroCreated(macro, macroIndex)
    BindNewMacro(macro, macroIndex)
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

function MegaMacroEngine.Uninstall()
    if InCombatLockdown() then
        return false
    end

    MegaMacroGlobalData.Activated = false
    MegaMacroCharacterData.Activated = false
    
    -- Loop every macro and remove the prefix
    for i=1, MacroLimits.MaxGlobalMacros + MacroLimits.MaxCharacterMacros do
        local code = GetMacroBody(i)
        local macroId = GetIdFromMacroCode(code)
        local macroName = GetMacroInfo(i)
        
        
        if macroId then
            local cleanCode = string.sub(code, 5)
            --If it is stubcode, replace with what we can.
            local macro = MegaMacro.GetById(macroId)
            if macro and #macro.Code > MegaMacroCodeMaxLengthForNative then
                cleanCode = macro.Code
            end

            local iconTexture = getTexture(macro, i)
            EditMacro(i, macroName, iconTexture, cleanCode, true, i > MacroLimits.MaxGlobalMacros)
        end
    end
    -- Now clear MegaMacro Global, Character, and Spec data
    MegaMacroGlobalData.Macros = {}
    MegaMacroCharacterData.Macros = {}
    MegaMacroGlobalData.Classes[MegaMacroCachedClass].Macros = {}
    MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization].Macros = {}
    MegaMacroGlobalData.InactiveMacros = {}

    InitializeMacroIndexCache()
    message("Mega Macro: Uninstalled. Disabled MegaMacro and reload your UI.")
    return true
end