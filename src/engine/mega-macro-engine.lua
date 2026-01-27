MegaMacroEngine = {}
local ClickyFrameName = "MegaMacroClicky"
local MacroIndexCache = {} -- caches native macro indexes
local Initialized = false

-- 12.0 Compatibility Helpers
local function GetMacroInfo(index)
    -- Try C_Macro first (12.0 standard)
    if C_Macro and C_Macro.GetMacroInfo then
        local info = C_Macro.GetMacroInfo(index)
        if info then
            return info.name, info.icon, info.body, info.isLocal
        end
    end
    -- Fallback for legacy/global
    if _G.GetMacroInfo then
        return _G.GetMacroInfo(index)
    end
end

local function GetNumMacros()
    if C_Macro and C_Macro.GetNumMacros then
        return C_Macro.GetNumMacros()
    end
    return _G.GetNumMacros()
end

local function EditMacro(...)
    if C_Macro and C_Macro.EditMacro then
        return C_Macro.EditMacro(...)
    end
    return _G.EditMacro(...)
end

local function CreateMacro(...)
    if C_Macro and C_Macro.CreateMacro then
        return C_Macro.CreateMacro(...)
    end
    return _G.CreateMacro(...)
end

local function DeleteMacro(...)
    if C_Macro and C_Macro.DeleteMacro then
        return C_Macro.DeleteMacro(...)
    end
    return _G.DeleteMacro(...)
end

local function PickupMacro(...)
    if C_Macro and C_Macro.PickupMacro then
        return C_Macro.PickupMacro(...)
    end
    return _G.PickupMacro(...)
end

local function GetActionInfo(slot)
    if C_ActionBar and C_ActionBar.GetActionInfo then
        return C_ActionBar.GetActionInfo(slot)
    end
    return _G.GetActionInfo(slot)
end

local function PickupAction(slot)
    if C_ActionBar and C_ActionBar.PickupAction then
        return C_ActionBar.PickupAction(slot)
    end
    return _G.PickupAction(slot)
end

local function PlaceAction(slot)
    if C_ActionBar and C_ActionBar.PlaceAction then
        return C_ActionBar.PlaceAction(slot)
    end
    return _G.PlaceAction(slot)
end


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
    if not macroCode or type(macroCode) ~= "string" then return nil end
    return tonumber(string.sub(macroCode, 2, 4))
end

local function InitializeMacroIndexCache()
    MacroIndexCache = {}

    -- 12.0: C_Macro.GetMacroInfo might return nil for empty slots, handled by helper
    for i=1, MacroLimits.MaxGlobalMacros do
        local _, _, macroCode = GetMacroInfo(i)
        if macroCode then
            local macroId = GetIdFromMacroCode(macroCode)
            if macroId then
                MacroIndexCache[macroId] = i
            end
        end
    end

    for i=1 + MacroLimits.MaxGlobalMacros, MacroLimits.MaxGlobalMacros + MacroLimits.MaxCharacterMacros do
        local _, _, macroCode = GetMacroInfo(i)
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
    local code = macro.Code or ""
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
        local _, indexIcon = GetMacroInfo(macroIndex)
        iconTexture = indexIcon
    end
    return iconTexture
end

function MegaMacroEngine.GetOrCreateClicky(macroId)
    local name = ClickyFrameName..macroId
    local clicky = _G[name]

    if not clicky then
        -- 12.0: SecureActionButtonTemplate requires strict inheritance
        clicky = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
        clicky:SetAttribute("type", "macro")
        clicky:SetAttribute("macrotext", "")
    end

    return clicky
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

local function BindMacro(macro, macroIndex)
    -- 12.0 Safety: Cannot edit macros or set attributes in combat
    if InCombatLockdown() then return end

    local macroIndex = macroIndex or MacroIndexCache[macro.Id]

    -- Bind code to macro
    if macroIndex then
        local iconTexture = getTexture(macro, macroIndex)
        local macroCode = macro.Code or ""

        if #macroCode <= MegaMacroCodeMaxLengthForNative then
            EditMacro(macroIndex, FormatMacroDisplayName(macro.DisplayName), iconTexture, GenerateNativeMacroCode(macro), true, macroIndex > MacroLimits.MaxGlobalMacros)
            -- Clean up clicky if it existed previously
            local clicky = _G[ClickyFrameName..macro.Id]
            if clicky then clicky:SetAttribute("macrotext", "") end
        else
            -- Extended Macro logic (>255 chars)
            local clicky = MegaMacroEngine.GetOrCreateClicky(macro.Id)
            clicky:SetAttribute("macrotext", macroCode)
            EditMacro(macroIndex, FormatMacroDisplayName(macro.DisplayName), iconTexture, MegaMacroEngine.GetMacroStubCode(macro.Id), true, macroIndex > MacroLimits.MaxGlobalMacros)
        end
        InitializeMacroIndexCache()
    end
end

local function BindNewMacro(macro, macroIndex)
    if InCombatLockdown() then return end
    
    local macroIndex = macroIndex or MacroIndexCache[macro.Id]

    if not macroIndex then
        -- Find a free slot. Need to know if global or character
        local isGlobal = macro.Scope == MegaMacroScopes.Global or macro.Scope == MegaMacroScopes.Class or macro.Scope == MegaMacroScopes.Specialization
        macroIndex = isGlobal and MegaMacroEngine.FindAvailableGlobalMacro() or MegaMacroEngine.FindAvailableCharacterMacro()
    end
    -- Bind code to macro
    if macroIndex then
        BindMacro(macro, macroIndex)
    end
end

-- Import Logic Wrappers
local function TryImportGlobalMacros()
    local numberOfGlobalMacros = GetNumMacros()

    for i=1, numberOfGlobalMacros do
        local name, iconTexture, body = GetMacroInfo(i)
        -- First, is it already a Mega Macro?
        local macroId = GetIdFromMacroCode(body)
        
        if not macroId and body then
            local macro = MegaMacro.Create(name, MegaMacroScopes.Global, iconTexture or MegaMacroTexture, true, body, i)

            if macro == nil then
                macro = MegaMacro.Create(name, MegaMacroScopes.Inactive, iconTexture or MegaMacroTexture, true, body, i)
                if macro == nil then
                    return false, "Failed to import at macro " .. i .. "(" .. (name or "?") .. "). Please delete the macro and reload your UI."
                end
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
        local name, iconTexture, body = GetMacroInfo(i)
        
        local macroId = GetIdFromMacroCode(body)

        if not macroId and body then
            local macro = MegaMacro.Create(name, MegaMacroScopes.Character, iconTexture or MegaMacroTexture, true, body, i)

            if macro == nil then
                macro = MegaMacro.Create(name, MegaMacroScopes.Inactive, iconTexture or MegaMacroTexture, true, body, i)
                if macro == nil then
                    return false, "Failed to import at macro " .. i .. "(" .. (name or "?") .. "). Please delete the macro and reload your UI."
                end
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
    local characterSpecializationMacros = MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization].Macros
    local characterMacros = MegaMacroCharacterData.Macros
    
    if not characterSpecializationMacros or #characterSpecializationMacros == 0 then
        return
    end
    
    for i=1, #characterSpecializationMacros do
        local macro = characterSpecializationMacros[i]
        
        if #characterMacros >= MacroLimits.MaxCharacterMacros then
            macro.Scope = MegaMacroScopes.Inactive
            macro.Id = MegaMacro.GetNextAvailableMacroId(MacroIndexOffsets.Inactive, MacroLimits.InactiveCount, MegaMacroGlobalData.InactiveMacros)
            table.insert(MegaMacroGlobalData.InactiveMacros, macro)
        else 
            macro.Scope = MegaMacroScopes.Character
            macro.Id = MegaMacro.GetNextAvailableMacroId(MacroIndexOffsets.NativeCharacterMacros, MacroLimits.MaxCharacterMacros, MegaMacroCharacterData.Macros)
            table.insert(characterMacros, macro)
        end
    end
    MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization].Macros = {}
end

function MegaMacroEngine.FindAvailableGlobalMacro()
    if InCombatLockdown() then return nil end

    local globalCount = GetNumMacros() -- returns (global, perChar)

    local usedMacroIndexes = {}
    for _, index in pairs(MacroIndexCache) do
        usedMacroIndexes[index] = true
    end

    local startIndex = 1
    local endIndex = MacroLimits.MaxGlobalMacros

    local hasFreeSlot = globalCount < MacroLimits.MaxGlobalMacros
    if hasFreeSlot then
        return CreateMacro(" ", MegaMacroTexture, " ", false)
    end

    for i=startIndex, endIndex do
        if not usedMacroIndexes[i] then
            return i
        end
    end
    
    for i=startIndex, endIndex do
        if usedMacroIndexes[i] and MegaMacroEngine.GetMacroIdFromIndex(i) > MacroIndexOffsets.Inactive then
            return i
        end
    end
    
    print("Mega Macro: Failed to find available global macro slot.")
    return nil
end

function MegaMacroEngine.FindAvailableCharacterMacro()
    if InCombatLockdown() then return nil end

    local _, characterCount = GetNumMacros()

    local usedMacroIndexes = {}
    for _, index in pairs(MacroIndexCache) do
        usedMacroIndexes[index] = true
    end

    local startIndex = 1 + MacroIndexOffsets.NativeCharacterMacros
    local endIndex = MacroLimits.MaxGlobalMacros + MacroLimits.MaxCharacterMacros

    local hasFreeSlot = characterCount < MacroLimits.MaxCharacterMacros
    if hasFreeSlot then
        local index = CreateMacro(" ", MegaMacroTexture, " ", true)
        return index
    end
    
    for i=startIndex, endIndex do
        if not usedMacroIndexes[i] then
            return i
        end
    end

    return nil
end

local function UnbindMacro(macro)
    if Initialized and not InCombatLockdown() then
        local macroIndex = MacroIndexCache[macro.Id]

        if macroIndex then
            local clicky = _G[ClickyFrameName..macro.Id]
            if clicky then 
                clicky:SetAttribute("macrotext", "")
            end
            EditMacro(macroIndex, " ", nil, GenerateIdPrefix(macro.Id), true, macroIndex > MacroLimits.MaxGlobalMacros)
            InitializeMacroIndexCache()
        end
    end
end

local function BindMacrosList(macroList)
    if not macroList then return end
    local count = #macroList
    for i=1, count do
        BindMacro(macroList[i])
    end
end

local function UnbindMacrosList(macroList)
    if not macroList then return end
    local count = #macroList
    for i=1, count do
        UnbindMacro(macroList[i])
    end
end

local function BindMacros()
    if InCombatLockdown() then return end
    
    BindMacrosList(MegaMacroGlobalData.Macros)

    if MegaMacroCachedClass and MegaMacroGlobalData.Classes[MegaMacroCachedClass] then
        BindMacrosList(MegaMacroGlobalData.Classes[MegaMacroCachedClass].Macros)

        if MegaMacroCachedSpecialization and MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization] then
            BindMacrosList(MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization].Macros)
        end
    end

    BindMacrosList(MegaMacroCharacterData.Macros)

    if MegaMacroCachedSpecialization and MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization] then
        BindMacrosList(MegaMacroCharacterData.Specializations[MegaMacroCachedSpecialization].Macros)
    end
end

local function PickupMacroWrapper(original, macroIndex)
    if InCombatLockdown() then return end
    
    if MegaMacroConfig and MegaMacroConfig['UseNativeActionBar'] then
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
    if InCombatLockdown() then return false end

    MergeCharacterSpecializationMacros()
    InitializeMacroIndexCache()
    Initialized = true
    BindMacros() 

    -- Hook PickupMacro
    local originalPickupMacro = PickupMacro
    -- Reassign the global to our wrapper? No, hook it or replace the pointer in this scope?
    -- The original code tried to overwrite the Global. In 12.0 this is risky but standard for this type of addon.
    if _G.PickupMacro then
        _G.PickupMacro = function(macroIndex) PickupMacroWrapper(originalPickupMacro, macroIndex) end
    end
    
    -- Also hook C_Macro if it exists
    if C_Macro and C_Macro.PickupMacro then
         local originalCPickup = C_Macro.PickupMacro
         C_Macro.PickupMacro = function(macroIndex) PickupMacroWrapper(originalCPickup, macroIndex) end
    end

    return true
end

function MegaMacroEngine.VerifyMacros()
    local numberOfGlobalMacros = GetNumMacros()

    for i=1, numberOfGlobalMacros do
        local name, _, body = GetMacroInfo(i)
        local macroId = GetIdFromMacroCode(body)
        
        if macroId then
            if macroId > MacroLimits.MaxGlobalMacros and macroId < MacroIndexOffsets.Inactive then
                print("Mega Macro: Found character macro in global space! " .. i .. " " .. (name or "") .. " #" .. macroId)
                DeleteMacro(i)
            end
        end
    end

    local _, numberOfCharacterMacros = GetNumMacros()
    for i=1 + MacroIndexOffsets.NativeCharacterMacros, numberOfCharacterMacros + MacroIndexOffsets.NativeCharacterMacros do
        local name, _, body = GetMacroInfo(i)
        local macroId = GetIdFromMacroCode(body)
        
        if macroId then
            if macroId < MacroIndexOffsets.NativeCharacterMacros then
                print("Mega Macro: Found global macro in character space! " .. i .. " " .. (name or "") .. " #" .. macroId)
                DeleteMacro(i)
            end
        end
    end

    InitializeMacroIndexCache()
    
    local macroIds = {}
    local function VerifyMacro(macro)
        if not macro then return end
        local macroId = macro.Id
        local macroIndex = MacroIndexCache[macro.Id]
        
        if macroIds[macroId] then
            -- Duplicate detected
        else
            macroIds[macroId] = true
        end

        if not macroIndex then
            print("Mega Macro: Fixing missing macro " .. macro.Id .. " " .. (macro.DisplayName or ""))
            BindNewMacro(macro)
        end
        return true
    end

    for i=1, #MegaMacroGlobalData.Macros do VerifyMacro(MegaMacroGlobalData.Macros[i]) end
    for i=1, #MegaMacroCharacterData.Macros do VerifyMacro(MegaMacroCharacterData.Macros[i]) end

    if MegaMacroCachedClass and MegaMacroGlobalData.Classes[MegaMacroCachedClass] then
        for i=1, #MegaMacroGlobalData.Classes[MegaMacroCachedClass].Macros do
            VerifyMacro(MegaMacroGlobalData.Classes[MegaMacroCachedClass].Macros[i])
        end
        if MegaMacroCachedSpecialization and MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization] then
            for i=1, #MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization].Macros do
                VerifyMacro(MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization].Macros[i])
            end
        end
    end
    
    InitializeMacroIndexCache()
end

function MegaMacroEngine.ImportMacros()
    if InCombatLockdown() then return false end

    local importSuccessful, errorMessage = TryImportGlobalMacros()
    if importSuccessful then
        MegaMacroGlobalData.Activated = true
    elseif errorMessage then
        message(errorMessage)
    end

    importSuccessful, errorMessage = TryImportCharacterMacros()
    if importSuccessful then
        MegaMacroCharacterData.Activated = true
    elseif errorMessage then
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
    if InCombatLockdown() then 
        print("Mega Macro: Cannot delete macros in combat.")
        return 
    end

    for i=1, 120 do
        local type, id = GetActionInfo(i)
        if type == "macro" and MegaMacroEngine.GetMacroIdFromIndex(id) == macro.Id then
            PickupAction(i)
            ClearCursor()
        end
    end

    UnbindMacro(macro)
end

function MegaMacroEngine.OnMacroMoved(oldMacro, newMacro)
    if InCombatLockdown() then return end

    for i=1, 120 do
        local type, id = GetActionInfo(i)
        if type == "macro" and MegaMacroEngine.GetMacroIdFromIndex(id) == oldMacro.Id then
            PickupMacro(MacroIndexCache[newMacro.Id])
            PlaceAction(i)
            ClearCursor()
        end
    end
end

function MegaMacroEngine.OnSpecializationChanged(oldValue, newValue)
    if InCombatLockdown() then return end
    if not MegaMacroCachedClass then return end

    if oldValue and MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[oldValue] then
        UnbindMacrosList(MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[oldValue].Macros)
    end
    if oldValue and MegaMacroCharacterData.Specializations[oldValue] then
        UnbindMacrosList(MegaMacroCharacterData.Specializations[oldValue].Macros)
    end

    if newValue and MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[newValue] then
        BindMacrosList(MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[newValue].Macros)
    end
    if newValue and MegaMacroCharacterData.Specializations[newValue] then
        BindMacrosList(MegaMacroCharacterData.Specializations[newValue].Macros)
    end
end

function MegaMacroEngine.Uninstall()
    if InCombatLockdown() then return false end

    MegaMacroGlobalData.Activated = false
    MegaMacroCharacterData.Activated = false
    
    -- Loop every macro and remove the prefix
    for i=1, MacroLimits.MaxGlobalMacros + MacroLimits.MaxCharacterMacros do
        local _, _, code = GetMacroInfo(i)
        local macroName = GetMacroInfo(i) -- get name
        
        local macroId = GetIdFromMacroCode(code)
        
        if macroId then
            local cleanCode = string.sub(code or "", 5)
            local macro = MegaMacro.GetById(macroId)
            
            if macro and macro.Code and #macro.Code > MegaMacroCodeMaxLengthForNative then
                cleanCode = macro.Code
            end

            local iconTexture = getTexture(macro, i)
            EditMacro(i, macroName, iconTexture, cleanCode, true, i > MacroLimits.MaxGlobalMacros)
        end
    end
    
    -- Now clear data
    MegaMacroGlobalData.Macros = {}
    MegaMacroCharacterData.Macros = {}
    if MegaMacroCachedClass then
        MegaMacroGlobalData.Classes[MegaMacroCachedClass].Macros = {}
        if MegaMacroCachedSpecialization then
            MegaMacroGlobalData.Classes[MegaMacroCachedClass].Specializations[MegaMacroCachedSpecialization].Macros = {}
        end
    end
    MegaMacroGlobalData.InactiveMacros = {}

    InitializeMacroIndexCache()
    message("Mega Macro: Uninstalled. Disabled MegaMacro and reload your UI.")
    return true
end