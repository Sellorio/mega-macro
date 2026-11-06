-- Supplies the icons shown in the icon picker.
--
-- Searching by name needs the name and icon of every spell in the game, which is a lot of
-- memory, so it's only gathered once a search needs it and released when the window closes.
-- Scanning and matching are spread over frames while the picker is open, and the results
-- fill in as they're found.

local FrameBudgetMs = 4
local StepsBetweenClockChecks = 64
local MinSearchLength = 3
local MaxResultsPerGroup = 300
-- Spell IDs have large gaps, so only give up after a long run of IDs with no spell
local MaxConsecutiveMisses = 100000
-- A gear icon, used by a lot of internal spells (courtesy of WeakAuras)
local PlaceholderSpellIcon = 136243

local GetSpellTexture = C_Spell.GetSpellTexture
local GetSpellName = C_Spell.GetSpellName or function(spellId)
    local spellInfo = C_Spell.GetSpellInfo(spellId)
    return spellInfo and spellInfo.name
end

-- One entry per distinct spell name and icon, in parallel arrays as a table per spell adds up
local EntryNames, EntryIcons, EntrySpellIds, EntryCount
local KnownIconsByName -- only needed while scanning
local NextSpellId, ConsecutiveMisses, IsScanFinished

local DefaultIcons = nil
local ExactIcon = nil
local CurrentSearch = nil

local function ResetSpellData()
    EntryNames, EntryIcons, EntrySpellIds, EntryCount = {}, {}, {}, 0
    KnownIconsByName = {}
    NextSpellId, ConsecutiveMisses, IsScanFinished = 0, 0, false
end

local function GetDefaultIconList()
    local icons = {}

	-- We need to avoid adding duplicate spellIDs from the spellbook tabs for your other specs.
	local activeIcons = {};

	for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local skillLine = C_SpellBook.GetSpellBookSkillLineInfo(i)
        local offset = skillLine.itemIndexOffset
        local numSpells = skillLine.numSpellBookItems
		offset = offset + 1;
		local tabEnd = offset + numSpells;
		for j = offset, tabEnd - 1 do
			--to get spell info by slot, you have to pass in a pet argument
			local spellType, ID = C_SpellBook.GetSpellBookItemType(j, Enum.SpellBookSpellBank.Player);
			if (spellType ~= "FUTURESPELL") then
				local fileID = C_SpellBook.GetSpellBookItemTexture(j, Enum.SpellBookSpellBank.Player);
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
							local fileID = C_Spell.GetSpellTexture(spellID);
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

	for i=1, #icons do
		if type(icons[i]) ~= "number" then
			icons[i] = "INTERFACE\\ICONS\\"..icons[i]
		end
    end

    return icons
end

-- Returns whether this name and icon pair hasn't been seen yet, and remembers it
local function RememberEntry(name, icon)
    local known = KnownIconsByName[name]

    if not known then
        KnownIconsByName[name] = icon
    elseif known == icon then
        return false
    elseif type(known) ~= "table" then
        KnownIconsByName[name] = { [known] = true, [icon] = true }
    elseif known[icon] then
        return false
    else
        known[icon] = true
    end

    return true
end

local function ScanNextSpell()
    NextSpellId = NextSpellId + 1
    local name = GetSpellName(NextSpellId)

    if not name then
        ConsecutiveMisses = ConsecutiveMisses + 1

        if ConsecutiveMisses > MaxConsecutiveMisses then
            IsScanFinished = true
            KnownIconsByName = nil
        end

        return
    end

    ConsecutiveMisses = 0

    local icon = GetSpellTexture(NextSpellId)

    if icon and icon ~= PlaceholderSpellIcon and #name > 0 then
        name = string.lower(name)

        if RememberEntry(name, icon) then
            EntryCount = EntryCount + 1
            EntryNames[EntryCount] = name
            EntryIcons[EntryCount] = icon
            EntrySpellIds[EntryCount] = NextSpellId
        end
    end
end

local function MatchNextEntry()
    local entry = CurrentSearch.NextEntry
    CurrentSearch.NextEntry = entry + 1

    local matchIndex = string.find(EntryNames[entry], CurrentSearch.Text, 1, true)

    if matchIndex and not CurrentSearch.FoundIcons[EntryIcons[entry]] then
        -- names that start with the search come before names that only contain it
        local group = matchIndex == 1 and CurrentSearch.Starts or CurrentSearch.Contains

        if #group < MaxResultsPerGroup then
            group[#group + 1] = entry
            CurrentSearch.FoundIcons[EntryIcons[entry]] = true
        end
    end
end

ResetSpellData()

MegaMacroIconNavigator = {}

-- Called each frame while the picker is open
function MegaMacroIconNavigator.OnUpdate()
    if not CurrentSearch then
        return
    end

    local stopTime = debugprofilestop() + FrameBudgetMs

    repeat
        for _=1, StepsBetweenClockChecks do
            if CurrentSearch.NextEntry <= EntryCount then
                MatchNextEntry()
            elseif not IsScanFinished then
                ScanNextSpell()
            else
                return
            end
        end
    until debugprofilestop() >= stopTime
end

function MegaMacroIconNavigator.SetSearch(searchText)
    searchText = searchText and string.lower(searchText) or ""
    CurrentSearch = nil
    ExactIcon = nil

    if #searchText < MinSearchLength then
        DefaultIcons = DefaultIcons or GetDefaultIconList()
    elseif string.find(searchText, "^%d+$") then
        ExactIcon = tonumber(searchText)
    else
        CurrentSearch = { Text = searchText, NextEntry = 1, Starts = {}, Contains = {}, FoundIcons = {} }
    end
end

function MegaMacroIconNavigator.GetResultCount()
    if ExactIcon then
        return 1
    elseif CurrentSearch then
        return #CurrentSearch.Starts + #CurrentSearch.Contains
    end

    return DefaultIcons and #DefaultIcons or 0
end

-- Returns the icon and, when the icon came from a spell, that spell's ID
function MegaMacroIconNavigator.GetResult(index)
    if ExactIcon then
        return index == 1 and ExactIcon or nil
    elseif CurrentSearch then
        local startsCount = #CurrentSearch.Starts
        local entry = index <= startsCount and CurrentSearch.Starts[index] or CurrentSearch.Contains[index - startsCount]

        if entry then
            return EntryIcons[entry], EntrySpellIds[entry]
        end

        return nil
    end

    return DefaultIcons and DefaultIcons[index]
end

-- The picker closed. Scanned spells are kept so reopening it doesn't start over.
function MegaMacroIconNavigator.EndSearch()
    CurrentSearch = nil
    ExactIcon = nil
    DefaultIcons = nil
end

-- The window closed, so let go of everything
function MegaMacroIconNavigator.Release()
    MegaMacroIconNavigator.EndSearch()
    ResetSpellData()
end
