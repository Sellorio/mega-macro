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

	-- We need to avoid adding duplicate spellIDs from the spellbook tabs for your other specs.
	local activeIcons = {};

	for i = 1, GetNumSpellTabs() do
		local tab, tabTex, offset, numSpells, _ = GetSpellTabInfo(i);
		offset = offset + 1;
		local tabEnd = offset + numSpells;
		for j = offset, tabEnd - 1 do
			--to get spell info by slot, you have to pass in a pet argument
			local spellType, ID = GetSpellBookItemInfo(j, "player");
			if (spellType ~= "FUTURESPELL") then
				local fileID = GetSpellBookItemTexture(j, "player");
				if (fileID) then
					activeIcons[fileID] = true;
				end
			end
			if (spellType == "FLYOUT") then
				local _, _, numSlots, isKnown = GetFlyoutInfo(ID);
				if (isKnown and numSlots > 0) then
					for k = 1, numSlots do
						local spellID
						spellID, _, isKnown = GetFlyoutSlotInfo(ID, k)
						if (isKnown) then
							local fileID = GetSpellTexture(spellID);
							if (fileID) then
								activeIcons[fileID] = true;
							end
						end
					end
				end
			end
		end
	end

	for fileDataID in pairs(activeIcons) do
		icons[#icons + 1] = fileDataID;
	end

	GetLooseMacroIcons(icons);
	GetLooseMacroItemIcons(icons);
	GetMacroIcons(icons);
	GetMacroItemIcons(icons);

	local iconListLength = #icons
	for i=1, iconListLength do
		if type(icons[i]) ~= "number" then
			icons[i] = "INTERFACE\\ICONS\\"..icons[i]
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

        AddRange(priorityResults, otherResults)
        return priorityResults
    else
        return GetDefaultIconList()
    end

end