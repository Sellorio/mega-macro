-- modifier checks return:
--  - Parse Result
--  - Success/Fail (Boolean)

local Colours = GetMegaMacroParsingColourData()
local GetCharacter, GetWord, ParseResult = GetMegaMacroParsingFunctions()

local MouseButtonNames = {
    "1",
    "2",
    "3",
    "4",
    "5",
    "LeftButton",
    "MiddleButton",
    "RightButton",
    "Button4",
    "Button5"
}

local ModifierKeyNames = {
    "alt",
    "shift",
    "ctrl",
    "shiftctrl",
    "shiftalt",
    "altctrl",
    "ctrlalt",
    "ctrlshift",
    "altshift",
    "ctrlshiftalt",
    "ctrlaltshift",
    "altshiftctrl",
    "altctrlshift",
    "shiftaltctrl",
    "shiftctrlalt",
    "AUTOLOOTTOGGLE",
    "STICKCAMERA",
    "SPLITSTACK",
    "PICKUPACTION",
    "COMPAREITEMS",
    "OPENALLBAGS",
    "QUESTWATCHTOGGLE",
    "SELFCAST"
}

local function IsNumber(word)
    local wordLength = #word

    if wordLength == 0 then
        return false
    end
    for i=1, wordLength do
        if not string.match(string.sub(word, i, i), "[0-9]") then
            return false
        end
    end

    return true
end

local function IsModifierSeparator(parsingContext)
    local nextChar = GetCharacter(parsingContext)
    if nextChar == ":" then
        return true
    end
    return false
end

local function NoModifier(parsingContext)
    if IsModifierSeparator(parsingContext) then
        return "", false
    end
    return "", true
end

local function NumberModifier(parsingContext)
    local hasModifier = IsModifierSeparator(parsingContext)
    if hasModifier then
        local word = GetWord(parsingContext, 1)
        local wordLength = #word
        if not IsNumber(word) then
            return "", false
        end
        local result = ParseResult(parsingContext, 1, Colours.Syntax)..ParseResult(parsingContext, wordLength, Colours.Number)
        return result, true
    end

    return "", false
end

local function OptionalWordModifier(parsingContext)
    local hasModifier = IsModifierSeparator(parsingContext)

    if hasModifier then
        local word = GetWord(parsingContext, 1)
        local wordLength = #word
        if wordLength == 0 then
            return "", false
        end
        return ParseResult(parsingContext, 1, Colours.Syntax)..ParseResult(parsingContext, wordLength, Colours.String), true
    else
        return "", true
    end
end

local function RequiredWordModifier(parsingContext)
    local hasModifier = IsModifierSeparator(parsingContext)

    if hasModifier then
        local word = GetWord(parsingContext, 1)
        local wordLength = #word
        if wordLength == 0 then
            return "", false
        end
        return
            ParseResult(parsingContext, 1, Colours.Syntax)..
            ParseResult(parsingContext, wordLength, Colours.String),
            true
    else
        return "", false
    end
end

local function GroupModifier(parsingContext)
    local hasModifier = IsModifierSeparator(parsingContext)

    if hasModifier then
        local word = GetWord(parsingContext, 1)
        if word ~= "party" and word ~= "raid" then
            return "", false
        end
        return
            ParseResult(parsingContext, 1, Colours.Syntax)..
            ParseResult(parsingContext, #word, Colours.String),
            true
    else
        return "", false
    end
end

local function KeyModifier(parsingContext)
    local hasModifier = IsModifierSeparator(parsingContext)

    if hasModifier then
        local word = GetWord(parsingContext, 1)
        for i=1, #ModifierKeyNames do
            if word == ModifierKeyNames[i] then
                return
                    ParseResult(parsingContext, 1, Colours.Syntax)..
                    ParseResult(parsingContext, #word, Colours.String),
                    true
            end
        end

        return "", false
    else
        return "", true
    end
end

local function MouseButtonModifier(parsingContext)
    local hasModifier = IsModifierSeparator(parsingContext)

    if hasModifier then
        local word = GetWord(parsingContext, 1)
        for i=1, #MouseButtonNames do
            if word == MouseButtonNames[i] then
                return
                    ParseResult(parsingContext, 1, Colours.Syntax)..
                    ParseResult(parsingContext, #word, Colours.String),
                    true
            end
        end
    end

    return "", false
end

local function TalentModifier(parsingContext)
    local hasModifier = IsModifierSeparator(parsingContext)

    if hasModifier then
        local row = GetWord(parsingContext, 1)
        if not IsNumber(row) then
            return "", false
        end
        local separator = GetCharacter(parsingContext, 1 + #row)
        if separator ~= "/" then
            return "", false
        end
        local col = GetWord(parsingContext, 1 + #row + 1)
        if not IsNumber(row) then
            return "", false
        end
        return
            ParseResult(parsingContext, 1, Colours.Syntax)..
            ParseResult(parsingContext, #row, Colours.Number)..
            ParseResult(parsingContext, 1, Colours.Number)..
            ParseResult(parsingContext, #col, Colours.Number),
            true
    else
        return "", false
    end
end

local Conditionals = {
	actionbar = NoModifier,
	bar = NumberModifier,
	bonusbar = NumberModifier,
	btn = MouseButtonModifier,
	button = MouseButtonModifier,
	canexitvehicle = NoModifier,
	channeling = NoModifier,
	channelling = NoModifier,
	combat = NoModifier,
	cursor = OptionalWordModifier,
	dead = NoModifier,
	equipped = RequiredWordModifier,
	exists = NoModifier,
	extrabar = NumberModifier,
	flyable = NoModifier,
	flying = NoModifier,
	form = NumberModifier,
	group = GroupModifier,
	harm = NoModifier,
	help = NoModifier,
	indoors = NoModifier,
	mod = KeyModifier,
	modifier = KeyModifier,
	mounted = NoModifier,
	none = NoModifier,
	outdoors = NoModifier,
	overridebar = NumberModifier,
	party = NoModifier,
	pet = RequiredWordModifier,
	petbattle = NoModifier,
	possessbar = NumberModifier,
	pvptalent = TalentModifier,
	raid = NoModifier,
	spec = NumberModifier,
	stance = NumberModifier,
	stealth = NoModifier,
	swimming = NoModifier,
	talent = TalentModifier,
	unithasvehicleui = NoModifier,
	vehicleui = NoModifier,
	worn = RequiredWordModifier,
}

function GetMegaMacroParsingConditionsData()
    return Conditionals
end