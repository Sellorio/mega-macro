local FetchesPerFrame = 1000

local IconLoadingStarted = false
local MissCount = 0
local CurrentSpellId = 0
local IconLoadingFinished = false
local CleanupPhase = false

local IconCache = {}
IconCacheKeys = {}

local function TableConcat(self, otherTable)
    local selfLength = #self
    for i=1, #otherTable do
        self[selfLength + i] = otherTable[i]
    end

    return self
end

MegaMacroIconNavigator = {}

function MegaMacroIconNavigator.BeginLoadingIcons()
    IconLoadingStarted = true
end

function MegaMacroIconNavigator.OnUpdate()
    if IconLoadingStarted and not IconLoadingFinished then
        for _=1, FetchesPerFrame do
            CurrentSpellId = CurrentSpellId + 1
            local name, _, icon = GetSpellInfo(CurrentSpellId)

            if icon == 136243 then
                -- 136243 is the a gear icon, we can ignore those spells (courtesy of WeakAuras)
                MissCount = 0
            elseif name then
                if #name > 0 and icon then
                    name = string.lower(name)
                    MissCount = 0
                    if not IconCache[name] then
                        table.insert(IconCacheKeys, name)
                    end
                    IconCache[name] = icon
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
                local icon = IconCache[key]
                if not presentIcons[icon] then
                    presentIcons[icon] = true
                    if index == 1 then
                        table.insert(priorityResults, IconCache[key])
                    else
                        table.insert(otherResults, IconCache[key])
                    end

                    resultCount = resultCount + 1

                    if resultCount > 300 then
                        break
                    end
                end
            end
        end
    else
        for _, key in ipairs(IconCacheKeys) do
            local icon = IconCache[key]
            if not presentIcons[icon] then
                presentIcons[icon] = true
                table.insert(otherResults, IconCache[key])

                resultCount = resultCount + 1

                if resultCount > 300 then
                    break
                end
            end
        end
    end

    return TableConcat(priorityResults, otherResults)
end