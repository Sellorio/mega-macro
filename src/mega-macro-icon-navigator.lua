local FetchesPerFrame = 1000

local IconLoadingStarted = false
local MissCount = 0
local CurrentSpellId = 0
local IconLoadingFinished = false
local CleanupPhase = false

local IconCache = {}
IconCacheKeys = {}

local function AddRange(self, otherTable)
    local selfLength = #self
    for i=1, #otherTable do
        self[selfLength + i] = otherTable[i]
    end
end

local function GetDefaultIconList()
    local icons = {}
    local activeIcons = {};

    -- 12.0 uses C_SpellBook for all spellbook-related queries
    -- Safety check for C_SpellBook existence
    if C_SpellBook then
        local numSkillLines = C_SpellBook.GetNumSpellBookSkillLines()
        for i = 1, numSkillLines do
            local skillLine = C_SpellBook.GetSpellBookSkillLineInfo(i)
            if skillLine then
                local offset = skillLine.itemIndexOffset + 1
                local numSpells = skillLine.numSpellBookItems
                local tabEnd = offset + numSpells

                for j = offset, tabEnd - 1 do
                    local spellType, ID = C_SpellBook.GetSpellBookItemType(j, Enum.SpellBookSpellBank.Player)
                    if (spellType ~= "FUTURESPELL") then
                        local fileID = C_SpellBook.GetSpellBookItemTexture(j, Enum.SpellBookSpellBank.Player)
                        if (fileID) then
                            activeIcons[fileID] = true
                        end
                    end

                    if (spellType == "FLYOUT") then
                        local _, _, numSlots, isKnown = C_Spell.GetFlyoutInfo(ID)
                        if (isKnown and numSlots > 0) then
                            for k = 1, numSlots do
                                local spellID, _
                                spellID, _, isKnown = C_Spell.GetFlyoutSlotInfo(ID, k)
                                if (isKnown) then
                                    local fileID = C_Spell.GetSpellTexture(spellID)
                                    if (fileID) then
                                        activeIcons[fileID] = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for fileDataID in pairs(activeIcons) do
        icons[#icons + 1] = fileDataID
    end

    -- 12.0 Fix: GetLooseMacroIcons and GetLooseMacroItemIcons are removed.
    -- We only need to call GetMacroIcons and GetMacroItemIcons from C_Macro.
    if C_Macro then
        if C_Macro.GetMacroIcons then
            local macroIcons = C_Macro.GetMacroIcons()
            if macroIcons then
                AddRange(icons, macroIcons)
            end
        end
        if C_Macro.GetMacroItemIcons then
            local itemIcons = C_Macro.GetMacroItemIcons()
            if itemIcons then
                AddRange(icons, itemIcons)
            end
        end
    end

    -- 12.0 Clean up: Blizzard prefers FileDataIDs (numbers)
    for i=1, #icons do
        local iconVal = icons[i]
        if type(iconVal) == "string" and not iconVal:find("\\") then
            -- If it's a legacy string name without a path, format it correctly
            icons[i] = "INTERFACE\\ICONS\\" .. iconVal
        end
    end

    for i=1, #icons do
        icons[i] = { Icon = icons[i], SpellId = nil }
    end

    return icons
end

MegaMacroIconNavigator = {}

function MegaMacroIconNavigator.BeginLoadingIcons()
    IconLoadingStarted = true
end

function MegaMacroIconNavigator.OnUpdate()
    if IconLoadingStarted and not IconLoadingFinished then
        for _=1, FetchesPerFrame do
            CurrentSpellId = CurrentSpellId + 1
            
            -- 12.0: C_Spell.GetSpellInfo returns a table. 
            local spellInfo = C_Spell.GetSpellInfo(CurrentSpellId)
            
            if spellInfo then
                local name = spellInfo.name
                local icon = spellInfo.iconID
                local spellId = spellInfo.spellID

                if icon == 136243 then
                    -- Ignore generic gear icons
                    MissCount = 0
                elseif name and #name > 0 and icon then
                    name = string.lower(name)
                    MissCount = 0
                    local cachedIconList = IconCache[name]
                    if not cachedIconList then
                        table.insert(IconCacheKeys, name)
                        cachedIconList = {}
                        IconCache[name] = cachedIconList
                    end
                    
                    local hasIcon = false
                    for i=1, #cachedIconList do
                        if cachedIconList[i].Icon == icon then
                            hasIcon = true
                            break
                        end
                    end
                    
                    if not hasIcon then
                        table.insert(cachedIconList, { SpellId = spellId, Icon = icon })
                    end
                else
                    MissCount = MissCount + 1
                end
            else
                MissCount = MissCount + 1
            end

            -- 12.0: Spell IDs now exceed 500,000. 
            if MissCount > 2000 then
                table.sort(IconCacheKeys)
                IconLoadingFinished = true
                CleanupPhase = true
                break
            end
        end
    elseif CleanupPhase then
        CleanupPhase = false
    end
end

function MegaMacroIconNavigator.Search(searchText)
    local priorityResults = {}
    local otherResults = {}
    local resultCount = 0
    local presentIcons = {}

    if searchText and #searchText > 2 then
        searchText = string.lower(searchText)
        -- Escape special characters for Lua pattern matching
        local escapedSearch = string.gsub(searchText, "([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")

        for _, key in ipairs(IconCacheKeys) do
            local index = string.find(key, escapedSearch)

            if index then
                local itemList = IconCache[key]
                for _, item in ipairs(itemList) do
                    if not presentIcons[item.Icon] then
                        presentIcons[item.Icon] = true
                        if index == 1 then
                            table.insert(priorityResults, item)
                        else
                            table.insert(otherResults, item)
                        end

                        resultCount = resultCount + 1
                        if resultCount > 500 then -- Increased limit for 12.0 UI
                            break
                        end
                    end
                end
            end
        end

        AddRange(priorityResults, otherResults)
        return priorityResults
    else
        return GetDefaultIconList()
    end
end