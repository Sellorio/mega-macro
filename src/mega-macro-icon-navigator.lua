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

MegaMacroIconNavigator = {}

function MegaMacroIconNavigator.BeginLoadingIcons()
    IconLoadingStarted = true
end

function MegaMacroIconNavigator.OnUpdate()
    if IconLoadingStarted and not IconLoadingFinished then
        for _=1, FetchesPerFrame do
            CurrentSpellId = CurrentSpellId + 1
            local name, _, icon, _, _, _, spellId = GetSpellInfo(CurrentSpellId)

            if icon == 136243 then
                -- 136243 is the a gear icon, we can ignore those spells (courtesy of WeakAuras)
                MissCount = 0
            elseif name then
                if #name > 0 and icon then
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
                        if cachedIconList[i] == icon then
                            hasIcon = true
                            break
                        end
                    end
                    if not hasIcon then
                        table.insert(cachedIconList, { SpellId = spellId, Icon = icon })
                    end
                end
            else
                MissCount = MissCount + 1

                if MissCount > 400 then
                    table.sort(IconCacheKeys)
                    IconLoadingFinished = true
                    CleanupPhase = true
                    break
                end
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

                        if resultCount > 300 then
                            break
                        end
                    end
                end
            end
        end
    else
        for _, key in ipairs(IconCacheKeys) do
            local itemList = IconCache[key]
            for _, item in ipairs(itemList) do
                if not presentIcons[item.Icon] then
                    presentIcons[item.Icon] = true
                    table.insert(otherResults, item)

                    resultCount = resultCount + 1

                    if resultCount > 300 then
                        break
                    end
                end
            end
        end
    end

    AddRange(priorityResults, otherResults)
    return priorityResults
end