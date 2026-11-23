-- Backups of every Mega Macro macro, and codes that carry a backup or a tab of macros to another
-- account or player. Backups are saved as the same code an export shows, so exporting one is free.
-- Single-macro codes are no longer made, but early ones can still be imported.
MegaMacroBackups = {}

local LibDeflate = LibStub("LibDeflate")
local AceSerializer = LibStub("AceSerializer-3.0")

local CodePrefix = "MM1:"
local DataVersion = 1
local Day = 24 * 60 * 60
-- Automatic backups thin out with age: the newest of each day for a week, of each week for a
-- month, and of each month for half a year. Each character's newest is kept too, since it's the
-- only copy of that character's tab.
local RetentionTiers = {
    { Age = 7 * Day, GetBucket = function(time) return date("%Y-%m-%d", time) end },
    { Age = 35 * Day, GetBucket = function(time) return math.floor(time / (7 * Day)) end },
    { Age = 183 * Day, GetBucket = function(time) return date("%Y-%m", time) end }
}
-- Enough to undo the last few restores
local BeforeRestoreBackupsKept = 3
local HasCheckedAutomaticBackup = false

local CodeKinds = {
    Backup = "Backup",
    Macro = "Macro",
    Macros = "Macros"
}

local BackupTypes = {
    Manual = "Manual",
    Automatic = "Automatic",
    BeforeRestore = "BeforeRestore",
    BeforeUninstall = "BeforeUninstall",
    Imported = "Imported"
}
MegaMacroBackups.Types = BackupTypes

-- Backups are matched to characters by GUID, since names can repeat (first names on Forever, names across realms)
local function GetCharacterId()
    local guid = UnitGUID("player")

    -- Restricted identity info can't be compared, so it's treated as unknown
    if issecretvalue and issecretvalue(guid) then
        return nil
    end

    return guid
end

-- Forever has no realms but gives characters a surname; elsewhere a name is only unique on its realm
local function GetCharacterName()
    local name, surname = UnitName("player")

    if MegaMacroIsForever then
        return surname and surname ~= "" and name .. " " .. surname or name
    end

    return name .. " - " .. (GetRealmName() or "")
end

local function GetBackups()
    if type(MegaMacroGlobalData.Backups) ~= "table" then
        MegaMacroGlobalData.Backups = {}
    end

    return MegaMacroGlobalData.Backups
end

local function IsKey(value)
    return type(value) == "string" or type(value) == "number"
end

-- Copies only the fields a macro saves. Codes can come from anywhere, so anything that doesn't
-- belong in the scope's list (a wrong ID, a repeated ID, more than the tab holds) is dropped.
local function CopyMacroList(list, scope, classKey, specializationKey)
    local result = {}
    local usedIds = {}
    local offset, count = MegaMacro.GetIdRange(scope)

    if type(list) ~= "table" or not offset then
        return result
    end

    for _, macro in ipairs(list) do
        local id = type(macro) == "table" and macro.Id
        local isInRange = type(id) == "number" and id > offset and id <= offset + count

        if isInRange and not usedIds[id] and type(macro.Code) == "string" and #result < MegaMacro.GetSlotCount(scope) then
            local texture = macro.StaticTexture
            usedIds[id] = true

            table.insert(result, {
                Id = id,
                Scope = scope,
                ScopedIndex = #result + 1,
                DisplayName = type(macro.DisplayName) == "string" and macro.DisplayName or "",
                Code = macro.Code,
                StaticTexture = (type(texture) == "number" or type(texture) == "string") and texture or nil,
                IsStaticTextureFallback = macro.IsStaticTextureFallback and true or false,
                Class = classKey,
                Specialization = specializationKey
            })
        end
    end

    return result
end

local function CopySpecializations(specializations, scope, classKey)
    local result = {}

    if type(specializations) == "table" then
        for key, data in pairs(specializations) do
            if IsKey(key) and type(data) == "table" then
                result[key] = { Macros = CopyMacroList(data.Macros, scope, classKey, key) }
            end
        end
    end

    return result
end

local function CopyClasses(classes)
    local result = {}

    if type(classes) == "table" then
        for key, data in pairs(classes) do
            if IsKey(key) and type(data) == "table" then
                result[key] = {
                    Macros = CopyMacroList(data.Macros, MegaMacroScopes.Class, key),
                    Specializations = CopySpecializations(data.Specializations, MegaMacroScopes.Specialization, key)
                }
            end
        end
    end

    return result
end

local function CopyCharacter(character)
    if type(character) ~= "table" then
        return nil
    end

    return {
        Id = type(character.Id) == "string" and character.Id or nil,
        Name = type(character.Name) == "string" and character.Name or nil,
        Class = IsKey(character.Class) and character.Class or nil,
        Macros = CopyMacroList(character.Macros, MegaMacroScopes.Character, character.Class),
        Specializations = CopySpecializations(character.Specializations, MegaMacroScopes.CharacterSpecialization, character.Class)
    }
end

local function TakeSnapshot()
    return {
        Version = DataVersion,
        Global = CopyMacroList(MegaMacroGlobalData.Macros, MegaMacroScopes.Global),
        Inactive = CopyMacroList(MegaMacroGlobalData.InactiveMacros, MegaMacroScopes.Inactive),
        Classes = CopyClasses(MegaMacroGlobalData.Classes),
        Character = CopyCharacter({
            Id = GetCharacterId(),
            Name = GetCharacterName(),
            Class = MegaMacroCachedClass,
            Macros = MegaMacroCharacterData.Macros,
            Specializations = MegaMacroCharacterData.Specializations
        })
    }
end

local function CountMacros(snapshot)
    local count = #snapshot.Global + #snapshot.Inactive

    for _, classData in pairs(snapshot.Classes) do
        count = count + #classData.Macros

        for _, specializationData in pairs(classData.Specializations) do
            count = count + #specializationData.Macros
        end
    end

    if snapshot.Character then
        count = count + #snapshot.Character.Macros

        for _, specializationData in pairs(snapshot.Character.Specializations) do
            count = count + #specializationData.Macros
        end
    end

    return count
end

-- Saved tables don't keep their key order, so keys are sorted to make the same macros give the same text
local function AppendCanonical(parts, value)
    local valueType = type(value)

    if valueType == "table" then
        local keys = {}
        for key in pairs(value) do
            table.insert(keys, key)
        end
        table.sort(keys, function(left, right)
            if type(left) ~= type(right) then
                return type(left) < type(right)
            end
            return left < right
        end)

        parts[#parts + 1] = "{"
        for _, key in ipairs(keys) do
            AppendCanonical(parts, key)
            AppendCanonical(parts, value[key])
        end
        parts[#parts + 1] = "}"
    elseif valueType == "string" then
        parts[#parts + 1] = "s" .. #value .. ":" .. value
    else
        parts[#parts + 1] = string.sub(valueType, 1, 1) .. tostring(value) .. ";"
    end
end

-- Tells whether two snapshots hold the same macros, without keeping a copy of either
local function GetFingerprint(snapshot)
    local parts = {}
    AppendCanonical(parts, snapshot)
    local text = table.concat(parts)
    local hash = 0

    for i=1, #text do
        hash = (hash * 31 + string.byte(text, i)) % 2147483647
    end

    return #text .. ":" .. hash
end

local function Encode(payload)
    local serialized = AceSerializer:Serialize(payload)
    return CodePrefix .. LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(serialized))
end

-- Returns the code's contents, or nothing if it isn't a code this version can read
local function Decode(code)
    if type(code) ~= "string" then
        return nil
    end

    -- Pasting can add spaces or line breaks, which the code never has
    code = string.gsub(code, "%s", "")

    if string.sub(code, 1, #CodePrefix) ~= CodePrefix then
        return nil
    end

    local compressed = LibDeflate:DecodeForPrint(string.sub(code, #CodePrefix + 1))
    local serialized = compressed and LibDeflate:DecompressDeflate(compressed)

    if not serialized then
        return nil
    end

    local isValid, payload = AceSerializer:Deserialize(serialized)

    if not isValid or type(payload) ~= "table" or type(payload.Version) ~= "number" or payload.Version > DataVersion then
        return nil
    end

    return payload
end

-- Removes automatic and before-restore backups that the retention rules don't keep. Manual,
-- imported and before-uninstall backups are never removed. The backup being restored always stays.
local function TrimBackups(keptBackup)
    local backups = GetBackups()
    local now = time()
    local keep = {}
    local beforeRestoreCount = 0
    local seenCharacters = {}
    local seenBuckets = {}

    for i=1, #RetentionTiers do
        seenBuckets[i] = {}
    end

    local newestFirst = {}
    for _, backup in ipairs(backups) do
        table.insert(newestFirst, backup)
    end
    table.sort(newestFirst, function(left, right) return (left.Time or 0) > (right.Time or 0) end)

    for _, backup in ipairs(newestFirst) do
        local backupTime = backup.Time or 0

        if backup.Type == BackupTypes.Automatic then
            local characterKey = backup.CharacterId or ""

            if not seenCharacters[characterKey] then
                seenCharacters[characterKey] = true
                keep[backup] = true
            end

            for i, tier in ipairs(RetentionTiers) do
                local bucket = tier.GetBucket(backupTime)

                if now - backupTime < tier.Age and not seenBuckets[i][bucket] then
                    seenBuckets[i][bucket] = true
                    keep[backup] = true
                end
            end
        elseif backup.Type == BackupTypes.BeforeRestore then
            beforeRestoreCount = beforeRestoreCount + 1
            keep[backup] = beforeRestoreCount <= BeforeRestoreBackupsKept
        else
            keep[backup] = true
        end
    end

    if keptBackup then
        keep[keptBackup] = true
    end

    for index=#backups, 1, -1 do
        if not keep[backups[index]] then
            table.remove(backups, index)
        end
    end
end

local function AddBackup(snapshot, backupType, name, fingerprint, keptBackup)
    local backup = {
        Time = time(),
        Name = name and name ~= "" and name or nil,
        Type = backupType,
        Character = snapshot.Character and snapshot.Character.Name,
        CharacterId = snapshot.Character and snapshot.Character.Id,
        Count = CountMacros(snapshot),
        Fingerprint = fingerprint or GetFingerprint(snapshot)
    }

    backup.Code = Encode({
        Kind = CodeKinds.Backup,
        Version = DataVersion,
        Time = backup.Time,
        Name = backup.Name,
        Data = snapshot
    })

    table.insert(GetBackups(), backup)
    TrimBackups(keptBackup)
    return backup
end

-- Newest first
function MegaMacroBackups.GetAll()
    local result = {}

    for _, backup in ipairs(GetBackups()) do
        table.insert(result, backup)
    end

    table.sort(result, function(left, right) return (left.Time or 0) > (right.Time or 0) end)
    return result
end

function MegaMacroBackups.Create(name)
    return AddBackup(TakeSnapshot(), BackupTypes.Manual, name)
end

-- Kept like a manual backup, so it's still there if Mega Macro comes back later
function MegaMacroBackups.CreateBeforeUninstall()
    return AddBackup(TakeSnapshot(), BackupTypes.BeforeUninstall)
end

-- Once a day for each character, at login, and only if their macros changed since their last backup
function MegaMacroBackups.CreateAutomaticBackup()
    -- Setup runs after every loading screen, but login is the only time that matters
    if not MegaMacroConfig.AutomaticBackups or HasCheckedAutomaticBackup then
        return
    end

    HasCheckedAutomaticBackup = true

    -- Old backups age out of the retention tiers even on days nothing new is saved
    TrimBackups()

    local characterId = GetCharacterId()
    local today = date("%Y-%m-%d")
    local latest

    for _, backup in ipairs(GetBackups()) do
        if backup.CharacterId == characterId and backup.Type ~= BackupTypes.Imported then
            if backup.Type == BackupTypes.Automatic and date("%Y-%m-%d", backup.Time) == today then
                return
            end

            if not latest or backup.Time >= latest.Time then
                latest = backup
            end
        end
    end

    local snapshot = TakeSnapshot()
    local fingerprint = GetFingerprint(snapshot)

    if CountMacros(snapshot) == 0 or (latest and latest.Fingerprint == fingerprint) then
        return
    end

    AddBackup(snapshot, BackupTypes.Automatic, nil, fingerprint)
end

function MegaMacroBackups.Delete(backup)
    local backups = GetBackups()

    for index, existing in ipairs(backups) do
        if existing == backup then
            table.remove(backups, index)
            return
        end
    end
end

-- The groups of tabs a restore can put back on their own
local RestoreParts = {
    Global = "Global",
    Class = "Class",                     -- this class's tab
    Specializations = "Specializations", -- this class's spec tabs
    OtherClasses = "OtherClasses",       -- class and spec tabs of every other class
    Character = "Character",             -- the character tab of whoever made the backup, put on this character's tab
    Inactive = "Inactive"
}
MegaMacroBackups.RestoreParts = RestoreParts

local function CountSpecializations(specializations)
    local count = 0

    for _, specializationData in pairs(specializations) do
        count = count + #specializationData.Macros
    end

    return count
end

-- Reads a backup's contents as they'd be restored, or nothing if it can't be read
local function ReadBackup(backup)
    local payload = Decode(backup.Code)

    if not payload or payload.Kind ~= CodeKinds.Backup or type(payload.Data) ~= "table" then
        return nil
    end

    local data = payload.Data
    local character = CopyCharacter(data.Character)

    return {
        Global = CopyMacroList(data.Global, MegaMacroScopes.Global),
        Inactive = CopyMacroList(data.Inactive, MegaMacroScopes.Inactive),
        Classes = CopyClasses(data.Classes),
        Character = character,
        IsSameCharacter = character ~= nil and character.Id ~= nil and character.Id == GetCharacterId()
    }
end

-- How many macros the backup has for each part, and whether its character tab can be restored here.
-- Nothing if the backup can't be read.
function MegaMacroBackups.GetRestoreInfo(backup)
    local contents = ReadBackup(backup)

    if not contents then
        return nil
    end

    local counts = {
        [RestoreParts.Global] = #contents.Global,
        [RestoreParts.Inactive] = #contents.Inactive,
        [RestoreParts.Class] = 0,
        [RestoreParts.Specializations] = 0,
        [RestoreParts.OtherClasses] = 0,
        [RestoreParts.Character] = 0
    }

    for classKey, classData in pairs(contents.Classes) do
        if classKey == MegaMacroCachedClass then
            counts[RestoreParts.Class] = #classData.Macros
            counts[RestoreParts.Specializations] = CountSpecializations(classData.Specializations)
        else
            counts[RestoreParts.OtherClasses] = counts[RestoreParts.OtherClasses] + #classData.Macros + CountSpecializations(classData.Specializations)
        end
    end

    if contents.Character then
        counts[RestoreParts.Character] = #contents.Character.Macros + CountSpecializations(contents.Character.Specializations)
    end

    return {
        Counts = counts,
        HasCharacter = contents.Character ~= nil,
        IsSameCharacter = contents.IsSameCharacter,
        CharacterName = contents.Character and contents.Character.Name
    }
end

-- Puts the chosen parts (a set of RestoreParts; nil for all) back the way the backup has them, and
-- leaves the rest as they are. Your macros are backed up first so this can be undone.
function MegaMacroBackups.Restore(backup, parts)
    if InCombatLockdown() then
        return false
    end

    local contents = ReadBackup(backup)

    if not contents then
        return false
    end

    -- Everything, except another character's tab, which has to be asked for
    if not parts then
        parts = {}
        for _, part in pairs(RestoreParts) do
            parts[part] = part ~= RestoreParts.Character or contents.IsSameCharacter
        end
    end

    AddBackup(TakeSnapshot(), BackupTypes.BeforeRestore, nil, nil, backup)

    MegaMacroEngine.ReplaceMacros(function()
        if parts[RestoreParts.Global] then
            MegaMacroGlobalData.Macros = contents.Global
        end

        if parts[RestoreParts.Inactive] then
            MegaMacroGlobalData.InactiveMacros = contents.Inactive
        end

        local currentClasses = MegaMacroGlobalData.Classes
        local classes = {}

        -- Other classes come wholesale from one side or the other
        for classKey, classData in pairs(parts[RestoreParts.OtherClasses] and contents.Classes or currentClasses) do
            if classKey ~= MegaMacroCachedClass then
                classes[classKey] = classData
            end
        end

        local currentClass = currentClasses[MegaMacroCachedClass] or { Macros = {}, Specializations = {} }
        local backupClass = contents.Classes[MegaMacroCachedClass] or { Macros = {}, Specializations = {} }

        classes[MegaMacroCachedClass] = {
            Macros = parts[RestoreParts.Class] and backupClass.Macros or currentClass.Macros,
            Specializations = parts[RestoreParts.Specializations] and backupClass.Specializations or currentClass.Specializations
        }

        MegaMacroGlobalData.Classes = classes

        -- Another character's tab can be copied onto this one too. Character macros only belong to
        -- whichever character holds them, so they're relabelled with this character's class.
        if parts[RestoreParts.Character] and contents.Character then
            local function SetClass(list)
                for _, macro in ipairs(list) do
                    macro.Class = MegaMacroCachedClass
                end
            end

            SetClass(contents.Character.Macros)
            for _, specializationData in pairs(contents.Character.Specializations) do
                SetClass(specializationData.Macros)
            end

            MegaMacroCharacterData.Macros = contents.Character.Macros
            MegaMacroCharacterData.Specializations = contents.Character.Specializations
        end

        -- A backup from an older version can have Forever's spec macros in more than one list
        MegaMacroMergeForeverSpecializations()
    end)

    return true
end

-- What a share code keeps of a macro. Its ID belongs to the sender's game macros, so it gets a new one.
local function GetSharedMacro(macro)
    return {
        DisplayName = macro.DisplayName,
        Code = macro.Code,
        StaticTexture = macro.StaticTexture,
        IsStaticTextureFallback = macro.IsStaticTextureFallback
    }
end

-- A tab's macros as they are now, to choose from when exporting. Data goes in the code.
function MegaMacroBackups.GetTabEntries(macros)
    local result = {}

    for _, macro in ipairs(macros) do
        local data = MegaMacroIconEvaluator.GetCachedData(macro.Id)

        table.insert(result, {
            Name = macro.DisplayName or "",
            Texture = data and data.Icon or macro.StaticTexture or MegaMacroTexture,
            Code = macro.Code or "",
            Data = GetSharedMacro(macro)
        })
    end

    return result
end

-- All the given macros in one code
function MegaMacroBackups.GetTabCode(macros)
    local shared = {}

    for _, macro in ipairs(macros) do
        table.insert(shared, GetSharedMacro(macro))
    end

    return Encode({ Kind = CodeKinds.Macros, Version = DataVersion, Macros = shared })
end

-- Adds a shared macro to the tab, or the Inactive tab if that's full. Returns nothing if neither has room.
local function AddSharedMacro(macroData, scope)
    if type(macroData) ~= "table" or type(macroData.Code) ~= "string" then
        return nil
    end

    local name = type(macroData.DisplayName) == "string" and macroData.DisplayName or ""
    local texture = macroData.StaticTexture
    texture = (type(texture) == "number" or type(texture) == "string") and texture or MegaMacroTexture
    local isFallback = macroData.IsStaticTextureFallback and true or false

    return scope and MegaMacro.Create(name, scope, texture, isFallback, macroData.Code)
        or MegaMacro.Create(name, MegaMacroScopes.Inactive, texture, isFallback, macroData.Code)
end

-- "Backup", "Macro" or "Macros" (a whole tab), or nothing if the code can't be read
function MegaMacroBackups.GetCodeKind(code)
    local payload = Decode(code)
    return payload and CodeKinds[payload.Kind]
end

local function GetMacroKey(name, code)
    return (type(name) == "string" and name or "") .. "\n" .. code
end

-- The macros in a tab code, to choose from before any are added. Nothing if it isn't a tab code.
-- Each one: { Name, Texture, Code, IsOnTab = the tab already has one with this name and text, Data }
function MegaMacroBackups.ReadTabCode(code, scope)
    local payload = Decode(code)

    if not payload or payload.Kind ~= CodeKinds.Macros or type(payload.Macros) ~= "table" then
        return nil
    end

    local onTab = {}
    for _, macro in ipairs(MegaMacro.GetMacrosOnTab(scope)) do
        if type(macro.Code) == "string" then
            onTab[GetMacroKey(macro.DisplayName, macro.Code)] = true
        end
    end

    local result = {}

    for _, macroData in ipairs(payload.Macros) do
        if type(macroData) == "table" and type(macroData.Code) == "string" then
            local texture = macroData.StaticTexture

            table.insert(result, {
                Name = type(macroData.DisplayName) == "string" and macroData.DisplayName or "",
                Texture = (type(texture) == "number" or type(texture) == "string") and texture or MegaMacroTexture,
                Code = macroData.Code,
                IsOnTab = onTab[GetMacroKey(macroData.DisplayName, macroData.Code)] or false,
                Data = macroData
            })
        end
    end

    return result
end

-- Adds shared macros to the tab, or the Inactive tab once that's full. Returns { Added, OnInactive, Skipped }.
local function AddSharedMacros(macroDataList, scope)
    local result = { Added = 0, OnInactive = 0, Skipped = 0 }

    for _, macroData in ipairs(macroDataList) do
        local macro = AddSharedMacro(macroData, scope)

        if not macro then
            result.Skipped = result.Skipped + 1
        elseif macro.Scope == MegaMacroScopes.Inactive and scope ~= MegaMacroScopes.Inactive then
            result.OnInactive = result.OnInactive + 1
        else
            result.Added = result.Added + 1
        end
    end

    return result
end

-- Adds the chosen entries from ReadTabCode
function MegaMacroBackups.AddFromTabCode(entries, scope)
    local macroDataList = {}

    for _, entry in ipairs(entries) do
        table.insert(macroDataList, entry.Data)
    end

    return AddSharedMacros(macroDataList, scope)
end

-- Adds what the code holds. Macros go on the given tab, or the Inactive tab once that's full.
-- A backup goes on the backup list, to restore from there.
-- Results: "Macro", macro | "Macros", { Added, OnInactive, Skipped } | "Backup", backup | "Duplicate", backup
-- | "Full" | nil when the code can't be read
function MegaMacroBackups.Import(code, scope)
    local payload = Decode(code)

    if not payload then
        return nil
    end

    if payload.Kind == CodeKinds.Macro and type(payload.Macro) == "table" then
        local macro = AddSharedMacro(payload.Macro, scope)

        if not macro then
            return type(payload.Macro.Code) == "string" and "Full" or nil
        end

        return CodeKinds.Macro, macro
    elseif payload.Kind == CodeKinds.Macros and type(payload.Macros) == "table" then
        local result = AddSharedMacros(payload.Macros, scope)

        if result.Added + result.OnInactive == 0 then
            return #payload.Macros > 0 and "Full" or nil
        end

        return CodeKinds.Macros, result
    elseif payload.Kind == CodeKinds.Backup and type(payload.Data) == "table" then
        local cleanCode = string.gsub(code, "%s", "")

        for _, existing in ipairs(GetBackups()) do
            if existing.Code == cleanCode then
                return "Duplicate", existing
            end
        end

        local snapshot = {
            Version = DataVersion,
            Global = CopyMacroList(payload.Data.Global, MegaMacroScopes.Global),
            Inactive = CopyMacroList(payload.Data.Inactive, MegaMacroScopes.Inactive),
            Classes = CopyClasses(payload.Data.Classes),
            Character = CopyCharacter(payload.Data.Character)
        }

        local backup = {
            Time = type(payload.Time) == "number" and payload.Time or time(),
            Name = type(payload.Name) == "string" and payload.Name or nil,
            Type = BackupTypes.Imported,
            Character = snapshot.Character and snapshot.Character.Name,
            CharacterId = snapshot.Character and snapshot.Character.Id,
            Count = CountMacros(snapshot),
            Fingerprint = GetFingerprint(snapshot),
            Code = cleanCode
        }

        table.insert(GetBackups(), backup)
        return CodeKinds.Backup, backup
    end

    return nil
end
