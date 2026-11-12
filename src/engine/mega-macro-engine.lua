MegaMacroEngine = {}
local ClickyFrameName = "MegaMacroClicky"
local MacroIndexCache = {} -- caches native macro indexes - these change based on macro name so they are not the id we'll use in the addon
local IsMacroIndexCacheStale = true -- starts stale so it can be read before setup, which waits out combat after a reload
local Initialized = false
-- Macros can't be edited in combat, so the ones changed then are bound when it ends
local MacrosToBindAfterCombat = {}
-- Retail's action bars 6 to 8 use slots 145 to 180. Slots a game version doesn't have are empty.
local ActionSlotCount = 180

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
    local id = macroCode and (string.match(macroCode, "^#(%d%d%d)\n") or string.match(macroCode, "^#(%d%d%d)$"))
    return id and tonumber(id)
end

local function RemoveIdFromMacroCode(macroCode)
    return GetIdFromMacroCode(macroCode) and string.gsub(macroCode, "^#%d%d%d\n?", "", 1) or macroCode
end

local function IsBlank(text)
    return not text or not string.find(text, "%S")
end

-- Inactive macros can sit anywhere, the rest have to be in the part of the list their ID is for
local function IsIdAllowedAtIndex(macroId, macroIndex)
    return macroId > MacroIndexOffsets.Inactive or (macroId > MacroLimits.MaxGlobalMacros) == (macroIndex > MacroLimits.MaxGlobalMacros)
end

local function InitializeMacroIndexCache()
    MacroIndexCache = {}
    IsMacroIndexCacheStale = false

    for i=1, MacroLimits.MaxGlobalMacros + MacroLimits.MaxCharacterMacros do
        local _, _, macroCode, _ = GetMacroInfo(i)
        local macroId = GetIdFromMacroCode(macroCode)

        if macroId and IsIdAllowedAtIndex(macroId, i) then
            MacroIndexCache[macroId] = i
        end
    end
end

local function GetMacroIndexCache()
    if IsMacroIndexCacheStale then
        InitializeMacroIndexCache()
    end

    return MacroIndexCache
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
    local macroIndex = macroIndex or GetMacroIndexCache()[macro.Id]
    local iconTexture = macro and macro.StaticTexture
    if macroIndex and not iconTexture then
        local _, iconTexture, _, _ = GetMacroInfo(macroIndex)
    end
    return iconTexture
end

local function BindMacro(macro, macroIndex)
    if InCombatLockdown() then
        if not next(MacrosToBindAfterCombat) then
            print("Mega Macro: Your macro changes will apply when combat ends.")
        end
        MacrosToBindAfterCombat[macro.Id] = macro
        return
    end

    local macroIndex = macroIndex or GetMacroIndexCache()[macro.Id]

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
    local macroIndex = macroIndex or GetMacroIndexCache()[macro.Id]

    if not macroIndex then
        -- Find a free slot. Need to know if global or character
        local isGlobal = macro.Scope == MegaMacroScopes.Global or macro.Scope == MegaMacroScopes.Class or macro.Scope == MegaMacroScopes.Specialization
        -- A full global list must not spill into the character list, where the ID isn't valid
        if isGlobal then
            macroIndex = MegaMacroEngine.FindAvailableGlobalMacro()
        else
            macroIndex = MegaMacroEngine.FindAvailableCharacterMacro()
        end
    end
    -- Bind code to macro
    BindMacro(macro, macroIndex)
end

local function FindMacroToImport(firstIndex, lastIndex)
    for i=firstIndex, lastIndex do
        local name, _, body = GetMacroInfo(i)

        if body and not GetIdFromMacroCode(body) and not (IsBlank(name) and IsBlank(body)) then
            return i
        end
    end
end

-- Importing can rename a macro, which re-sorts the list, so each macro starts the search again
local function ImportMacrosInRange(firstIndex, lastIndex, scope)
    for _=firstIndex, lastIndex do
        local macroIndex = FindMacroToImport(firstIndex, lastIndex)

        if not macroIndex then
            return
        end

        local name = GetMacroInfo(macroIndex)
        local macro = MegaMacroEngine.ImportNativeMacro(macroIndex, scope)
            or MegaMacroEngine.ImportNativeMacro(macroIndex, MegaMacroScopes.Inactive)

        if not macro then
            print("Mega Macro: There's no room to import " .. name .. ". Anything not imported is listed on the Inactive tab.")
            return
        end
    end
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
        for _, index in pairs(GetMacroIndexCache()) do
            usedMacroIndexes[index] = true
        end

        local startIndex = 1
        local endIndex = MacroLimits.MaxGlobalMacros

        -- If there is a free slot, use that first.
        local hasFreeSlot = globalCount < MacroLimits.MaxGlobalMacros
        if hasFreeSlot then
            return CreateMacro(" ", MegaMacroTexture, " ", false)
        end

        -- Didn't find a free slot. An inactive macro stays saved without one. Other macros aren't ours to replace.
        -- Callers say when there's no room, since login checks would otherwise repeat it every time.
        for i=startIndex, endIndex do
            local macroId = usedMacroIndexes[i] and MegaMacroEngine.GetMacroIdFromIndex(i)
            if macroId and macroId > MacroIndexOffsets.Inactive and MegaMacro.GetById(macroId) then
                return i
            end
        end
        return nil
    end
end

function MegaMacroEngine.FindAvailableCharacterMacro()
    if not InCombatLockdown() then
        local _, characterCount = GetNumMacros()

        local hasFreeSlot = characterCount < MacroLimits.MaxCharacterMacros
        if hasFreeSlot then
            local index = CreateMacro(" ", MegaMacroTexture, " ", true)
            -- print("Mega Macro: Created new character macro at index " .. index .. ".")
            return index
        end

        return nil
    end
end

function MegaMacroEngine.GetOrCreateClicky(macroId)
    local name = ClickyFrameName..macroId
    local clicky = _G[name]

    if not clicky then
        clicky = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
        clicky:SetAttribute("type", "macro")
        clicky:SetAttribute("macrotext", "")
    end

    return clicky
end

local function UnbindMacro(macro)
    if Initialized then
        local macroIndex = GetMacroIndexCache()[macro.Id]

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

    -- Only change the icon of our own macros
    if macroId and not MegaMacro.GetById(macroId) then
        macroId = nil
    end

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

    if not MegaMacroIsForever then
        local originalPickupMacro = PickupMacro
        PickupMacro = function(macroIndex) PickupMacroWrapper(originalPickupMacro, macroIndex) end
    end

    return true
end

-- Points action bar buttons that use one game macro at another
local function MoveActionBarButtons(oldIndex, newIndex)
    for i=1, ActionSlotCount do
        local actionType, actionId = GetActionInfo(i)
        if actionType == "macro" and actionId == oldIndex then
            PickupMacro(newIndex)
            PlaceAction(i)
            ClearCursor()
        end
    end
end

-- When the global list was full, older versions could put a global, class or spec macro in the
-- character list. Once the real one is back in the global list, the stray copy is removed.
local function RemoveStrayCharacterCopies()
    for _=1, MacroLimits.MaxCharacterMacros do
        local strayIndex

        for i=MacroLimits.MaxGlobalMacros + 1, MacroLimits.MaxGlobalMacros + MacroLimits.MaxCharacterMacros do
            local _, _, body = GetMacroInfo(i)
            local macroId = GetIdFromMacroCode(body)

            if macroId and macroId <= MacroLimits.MaxGlobalMacros and GetMacroIndexCache()[macroId] and MegaMacro.IsKnownId(macroId) then
                strayIndex = i
                MoveActionBarButtons(i, GetMacroIndexCache()[macroId])
                break
            end
        end

        if not strayIndex then
            return
        end

        DeleteMacro(strayIndex)
        InitializeMacroIndexCache()
    end
end

function MegaMacroEngine.VerifyMacros()
    if InCombatLockdown() then
        return
    end

    InitializeMacroIndexCache()

    -- An addon that rewrites its macro drops our ID. Remaking our copy would leave two of them.
    local plainMacroNames = {}
    for i=1, MacroLimits.MaxGlobalMacros + MacroLimits.MaxCharacterMacros do
        local name, _, body = GetMacroInfo(i)
        if body and not GetIdFromMacroCode(body) then
            plainMacroNames[name] = true
        end
    end

    -- Verify that every macro in the addon is in the macro index cache. If not, we need to make a new macro. Also check duplicates
    local macroIds = {}
    local unplacedCount = 0
    local restoredCount = 0
    local function VerifyMacro(macro, i)
        local macroId = macro.Id
        local macroIndex = GetMacroIndexCache()[macro.Id]
        -- Check for duplicate macroIds
        if macroIds[macroId] then
            -- print("Mega Macro: Found duplicate macroId " .. macroId .. " " .. macro.DisplayName)
        else
            macroIds[macroId] = true
        end
        -- Check for missing macroIndex
        if not macroIndex and not plainMacroNames[FormatMacroDisplayName(macro.DisplayName)] then
            BindNewMacro(macro)

            -- With no room it stays missing, so it's only reported when that number goes up
            if GetMacroIndexCache()[macro.Id] then
                restoredCount = restoredCount + 1
            else
                unplacedCount = unplacedCount + 1
            end
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
    RemoveStrayCharacterCopies()

    if restoredCount == 1 then
        print("Mega Macro: Restored 1 missing macro.")
    elseif restoredCount > 1 then
        print("Mega Macro: Restored " .. restoredCount .. " missing macros.")
    end

    if unplacedCount > (MegaMacroCharacterData.UnplacedMacroCount or 0) then
        print("Mega Macro: " .. unplacedCount .. " of your macros can't be used right now because there's no room for them. Import or delete macros on the Inactive tab to make room.")
    end
    MegaMacroCharacterData.UnplacedMacroCount = unplacedCount

    local unmanagedCount = #MegaMacroEngine.GetUnmanagedMacros()
    local newCount = unmanagedCount - (MegaMacroCharacterData.UnmanagedMacroCount or 0)
    if newCount == 1 then
        print("Mega Macro: 1 new macro isn't managed by Mega Macro. It's listed on the Inactive tab, drag it to another tab to import it.")
    elseif newCount > 1 then
        print("Mega Macro: " .. newCount .. " new macros aren't managed by Mega Macro. They're listed on the Inactive tab, drag one to another tab to import it.")
    end
    MegaMacroCharacterData.UnmanagedMacroCount = unmanagedCount
end

-- Macros are only imported the first time. After that the Inactive tab lists anything new,
-- because rewriting a macro that belongs to another addon breaks it.
function MegaMacroEngine.ImportMacros()
    if InCombatLockdown() then
        return false
    end

    if not MegaMacroGlobalData.Activated then
        ImportMacrosInRange(1, MacroLimits.MaxGlobalMacros, MegaMacroScopes.Global)
        MegaMacroGlobalData.Activated = true
    end

    if not MegaMacroCharacterData.Activated then
        ImportMacrosInRange(1 + MacroIndexOffsets.NativeCharacterMacros, MacroIndexOffsets.NativeCharacterMacros + MacroLimits.MaxCharacterMacros, MegaMacroScopes.Character)
        MegaMacroCharacterData.Activated = true
    end

    InitializeMacroIndexCache()
end

-- True when a macro we have no saved data for still has this ID, so a new macro mustn't take it
function MegaMacroEngine.IsIdHeldByUnknownMacro(macroId)
    local macroIndex = GetMacroIndexCache()[macroId]

    if not macroIndex or MegaMacro.IsKnownId(macroId) then
        return false
    end

    local _, _, body = GetMacroInfo(macroIndex)
    return not IsBlank(RemoveIdFromMacroCode(body))
end

-- Macros in the game's list that aren't ours: other addons', ones with no saved data, and spare copies
function MegaMacroEngine.GetUnmanagedMacros()
    local cache = GetMacroIndexCache()
    local macros = {}

    for i=1, MacroLimits.MaxGlobalMacros + MacroLimits.MaxCharacterMacros do
        local name, iconTexture, body = GetMacroInfo(i)
        local macroId = GetIdFromMacroCode(body)
        local isManaged = macroId and cache[macroId] == i and MegaMacro.IsKnownId(macroId)
        local code = RemoveIdFromMacroCode(body)

        if body and not isManaged and not (IsBlank(code) and (macroId or IsBlank(name))) then
            local isTextLost = macroId and string.find(body, ClickyFrameName, 1, true) and true or false

            table.insert(macros, {
                IsUnmanaged = true,
                IsTextLost = isTextLost,
                HeldId = macroId and cache[macroId] == i and macroId or nil,
                NativeIndex = i,
                NativeBody = body,
                DisplayName = name,
                StaticTexture = iconTexture or MegaMacroTexture,
                Code = isTextLost and "-- This macro's text was lost." or code
            })
        end
    end

    return macros
end

-- Macro indexes shift when the list changes, so check it's still the same macro
function MegaMacroEngine.FindUnmanagedMacroIndex(unmanagedMacro)
    local function Matches(i)
        local name, _, body = GetMacroInfo(i)
        return name == unmanagedMacro.DisplayName and body == unmanagedMacro.NativeBody
    end

    if Matches(unmanagedMacro.NativeIndex) then
        return unmanagedMacro.NativeIndex
    end

    for i=1, MacroLimits.MaxGlobalMacros + MacroLimits.MaxCharacterMacros do
        if Matches(i) then
            return i
        end
    end
end

function MegaMacroEngine.DeleteUnmanagedMacro(unmanagedMacro)
    local macroIndex = MegaMacroEngine.FindUnmanagedMacroIndex(unmanagedMacro)

    if macroIndex then
        -- A spare copy of one of our macros hands its action bar spots to the real one
        local _, _, body = GetMacroInfo(macroIndex)
        local macroId = GetIdFromMacroCode(body)
        local realIndex = macroId and MegaMacro.IsKnownId(macroId) and GetMacroIndexCache()[macroId]

        if realIndex and realIndex ~= macroIndex then
            MoveActionBarButtons(macroIndex, realIndex)
        end

        DeleteMacro(macroIndex)
        InitializeMacroIndexCache()
    end
end

-- The first ID the scope can take that no game macro has
local function FindIdWithoutMacro(scope)
    local offset, count = MegaMacro.GetIdRange(scope)

    for macroId=offset + 1, offset + count do
        if not GetMacroIndexCache()[macroId] and MegaMacro.CanUseId(scope, macroId) then
            return macroId
        end
    end
end

-- Turns a macro from the game's list into a Mega Macro. Returns nothing if there's no room.
function MegaMacroEngine.ImportNativeMacro(macroIndex, scope)
    local name, iconTexture, body = GetMacroInfo(macroIndex)
    local isTextLost = GetIdFromMacroCode(body) and string.find(body, ClickyFrameName, 1, true)
    local code = isTextLost and "" or RemoveIdFromMacroCode(body)
    local isGlobalScope = scope == MegaMacroScopes.Global or scope == MegaMacroScopes.Class or scope == MegaMacroScopes.Specialization
    local isSameList = scope == MegaMacroScopes.Inactive or isGlobalScope == (macroIndex <= MacroLimits.MaxGlobalMacros)
    -- A macro left from lost saved data keeps its ID if it fits the tab, since every ID may be held by others like it
    local ownId = GetIdFromMacroCode(body)
    local keepsOwnId = isSameList and ownId and GetMacroIndexCache()[ownId] == macroIndex and MegaMacro.CanUseId(scope, ownId)
    local preferredId = keepsOwnId and ownId or nil
    -- A blank macro can still hold the ID (a deleted macro, or a class or spec slot the action bars use), so that one is reused
    local nextId = MegaMacro.GetNextIdInScope(scope)
    local isIdInList = not preferredId and nextId and GetMacroIndexCache()[nextId]
    local macro

    -- An inactive macro doesn't need a game macro, so it stays where it is under an ID that has none.
    -- Reusing a blank one would put an account macro in this character's list.
    if isIdInList and scope == MegaMacroScopes.Inactive then
        preferredId = FindIdWithoutMacro(scope)
        isIdInList = not preferredId
    end

    if isSameList and not isIdInList then
        -- Converting it where it is keeps it on any action bars
        macro = MegaMacro.Create(name, scope, iconTexture or MegaMacroTexture, true, code, macroIndex, preferredId)
    else
        macro = MegaMacro.Create(name, scope, iconTexture or MegaMacroTexture, true, code)

        -- Callers say when there's no room, since the first import tries the Inactive tab next
        if macro and not GetMacroIndexCache()[macro.Id] then
            MegaMacro.Delete(macro)
            return nil
        end

        if macro then
            -- Adding our macro shifted the list
            local oldIndex = MegaMacroEngine.FindUnmanagedMacroIndex({ NativeIndex = macroIndex, DisplayName = name, NativeBody = body })

            if oldIndex then
                MoveActionBarButtons(oldIndex, GetMacroIndexCache()[macro.Id])
                DeleteMacro(oldIndex)
                InitializeMacroIndexCache()
            end
        end
    end

    return macro
end

-- How many more macros this tab can really take. Besides the tab's own limit, each one needs a free ID
-- and a place in the game's macro list, and macros on the Inactive tab can be using both.
function MegaMacroEngine.GetAvailableSlotCount(scope)
    local room = MegaMacro.GetSlotCount(scope) - #MegaMacro.GetMacrosInScope(scope)
    local offset, count = MegaMacro.GetIdRange(scope)

    if room <= 0 or not offset or scope == MegaMacroScopes.Inactive then
        return math.max(room, 0)
    end

    local usedIds = {}
    for _, macro in ipairs(MegaMacro.GetMacrosInScope(scope)) do
        usedIds[macro.Id] = true
    end

    -- An ID that already has a game macro (a blank one, or a slot another class shares) reuses it
    local cache = GetMacroIndexCache()
    local idsWithMacro, idsNeedingMacro = 0, 0
    for macroId=offset + 1, offset + count do
        if not usedIds[macroId] and not MegaMacroEngine.IsIdHeldByUnknownMacro(macroId) then
            if cache[macroId] then
                idsWithMacro = idsWithMacro + 1
            else
                idsNeedingMacro = idsNeedingMacro + 1
            end
        end
    end

    local isGlobal = scope == MegaMacroScopes.Global or scope == MegaMacroScopes.Class or scope == MegaMacroScopes.Specialization
    local globalCount, characterCount = GetNumMacros()
    local freeMacros = isGlobal and MacroLimits.MaxGlobalMacros - globalCount or MacroLimits.MaxCharacterMacros - characterCount

    -- New global macros can also take the place of an inactive macro
    if isGlobal then
        for macroId, macroIndex in pairs(cache) do
            if macroIndex <= MacroLimits.MaxGlobalMacros and macroId > MacroIndexOffsets.Inactive and MegaMacro.GetById(macroId) then
                freeMacros = freeMacros + 1
            end
        end
    end

    return math.min(room, idsWithMacro + math.min(math.max(freeMacros, 0), idsNeedingMacro))
end

-- Macros left by Mega Macro whose saved data was lost (a new PC, a reinstall, a deleted WTF folder).
-- Global and character IDs each belong to one tab, so those can go back on their own.
-- Class and spec IDs are shared by every class, so nothing says which class one was for.
function MegaMacroEngine.GetRecoveryInfo()
    local info = { Recoverable = {}, GlobalCount = 0, CharacterCount = 0, ClassOrSpecCount = 0, LostCount = 0 }

    for _, macro in ipairs(MegaMacroEngine.GetUnmanagedMacros()) do
        local macroId = macro.HeldId

        if macro.IsTextLost then
            info.LostCount = info.LostCount + 1
        elseif macroId then
            local scope

            if macroId <= MacroIndexOffsets.PerClass then
                scope = MegaMacroScopes.Global
            elseif macroId > MacroIndexOffsets.PerCharacter and macroId <= MacroIndexOffsets.PerCharacterSpecialization then
                scope = MegaMacroScopes.Character
            elseif macroId <= MacroIndexOffsets.PerCharacter then
                info.ClassOrSpecCount = info.ClassOrSpecCount + 1
            end

            if scope and MegaMacro.CanUseId(scope, macroId) then
                table.insert(info.Recoverable, { Macro = macro, Scope = scope })

                if scope == MegaMacroScopes.Global then
                    info.GlobalCount = info.GlobalCount + 1
                else
                    info.CharacterCount = info.CharacterCount + 1
                end
            end
        end
    end

    return info
end

-- Imports every recoverable macro where it is, keeping its ID and action bar spots. Returns how many were imported.
function MegaMacroEngine.RecoverMacros()
    if InCombatLockdown() then
        return 0
    end

    local recovered = 0
    local failed = {}

    -- Importing can re-sort the list, so look again after each one
    for _=1, MacroLimits.MaxGlobalMacros + MacroLimits.MaxCharacterMacros do
        local item

        for _, candidate in ipairs(MegaMacroEngine.GetRecoveryInfo().Recoverable) do
            if not failed[candidate.Macro.DisplayName .. "\n" .. candidate.Macro.NativeBody] then
                item = candidate
                break
            end
        end

        if not item then
            break
        end

        local macroIndex = MegaMacroEngine.FindUnmanagedMacroIndex(item.Macro)

        if macroIndex and MegaMacroEngine.ImportNativeMacro(macroIndex, item.Scope) then
            recovered = recovered + 1
        else
            failed[item.Macro.DisplayName .. "\n" .. item.Macro.NativeBody] = true
        end
    end

    return recovered
end

function MegaMacroEngine.GetMacroIdFromIndex(macroIndex)
    for id, index in pairs(GetMacroIndexCache()) do
        if index == macroIndex then
            return id
        end
    end

    return nil
end

function MegaMacroEngine.GetMacroIndexFromId(macroId)
    return GetMacroIndexCache()[macroId]
end

-- The game's macro window and other addons can add or remove macros, which shifts every index after them
function MegaMacroEngine.OnNativeMacrosChanged()
    IsMacroIndexCacheStale = true
end

function MegaMacroEngine.BindMacrosChangedInCombat()
    for id, macro in pairs(MacrosToBindAfterCombat) do
        MacrosToBindAfterCombat[id] = nil
        BindMacro(macro)
    end
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
        for i=1, ActionSlotCount do
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
        for i=1, ActionSlotCount do
            local type, id = GetActionInfo(i)
            local newMacroIndex = GetMacroIndexCache()[newMacro.Id]
            if newMacroIndex and type == "macro" and MegaMacroEngine.GetMacroIdFromIndex(id) == oldMacro.Id then
                PickupMacro(newMacroIndex)
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
        local _, _, code, _ = GetMacroInfo(i)
        local macroId = GetIdFromMacroCode(code)
        local macroName, _, _, _ = GetMacroInfo(i)
        
        
        if macroId then
            local cleanCode = RemoveIdFromMacroCode(code)
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
    local classData = MegaMacroGlobalData.Classes[MegaMacroCachedClass]
    if classData then
        classData.Macros = {}
        if classData.Specializations[MegaMacroCachedSpecialization] then
            classData.Specializations[MegaMacroCachedSpecialization].Macros = {}
        end
    end
    MegaMacroGlobalData.InactiveMacros = {}

    InitializeMacroIndexCache()
    print("Mega Macro: Uninstalled. Disable MegaMacro and reload your UI.")
    return true
end