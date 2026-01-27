-- modifier checks return:
--  - Parse Result
--  - Success/Fail (Boolean)

-- Lazy load these to prevent load-order nil errors
local Colours = nil
local GetCharacter, GetWord, ParseResult = nil, nil, nil

local function InitializeDependencies()
    if not Colours and GetMegaMacroParsingColourData then
        Colours = GetMegaMacroParsingColourData()
    end
    if not GetCharacter and GetMegaMacroParsingFunctions then
        GetCharacter, GetWord, ParseResult = GetMegaMacroParsingFunctions()
    end
end

local MouseButtonNames = {
    "1", "2", "3", "4", "5",
    "LeftButton", "MiddleButton", "RightButton", "Button4", "Button5"
}

local ModifierKeyNames = {
    "alt", "shift", "ctrl",
    "shiftctrl", "shiftalt", "altctrl", "ctrlalt", "ctrlshift", "altshift",
    "ctrlshiftalt", "ctrlaltshift", "altshiftctrl", "altctrlshift", "shiftaltctrl", "shiftctrlalt",
    "AUTOLOOTTOGGLE", "STICKCAMERA", "SPLITSTACK", "PICKUPACTION", "COMPAREITEMS",
    "OPENALLBAGS", "QUESTWATCHTOGGLE", "SELFCAST"
}

local function IsNumber(word)
    if not word or #word == 0 then return false end
    return not string.match(word, "%D") -- Returns true if no non-digits are found
end

local function IsModifierSeparator(parsingContext)
    InitializeDependencies()
    local nextChar = GetCharacter(parsingContext)
    return nextChar == ":"
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
        return ParseResult(parsingContext, 1, Colours.Syntax)..ParseResult(parsingContext, wordLength, Colours.Number), true
    end
    return "", false
end

local function MultiNumberModifier(parsingContext)
    local hasModifier = IsModifierSeparator(parsingContext)
    if hasModifier then
        local word = GetWord(parsingContext, 1)
        local wordLength = #word

        -- Check for a single number or a sequence of numbers separated by slashes (e.g. 1/2/3)
        if word:match("^[%d/]+$") then
            return ParseResult(parsingContext, 1, Colours.Syntax)..ParseResult(parsingContext, wordLength, Colours.Number), true
        else
            return "", false
        end
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
        return ParseResult(parsingContext, 1, Colours.Syntax)..ParseResult(parsingContext, wordLength, Colours.String), true
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
        return ParseResult(parsingContext, 1, Colours.Syntax)..ParseResult(parsingContext, #word, Colours.String), true
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
                return ParseResult(parsingContext, 1, Colours.Syntax)..ParseResult(parsingContext, #word, Colours.String), true
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
                return ParseResult(parsingContext, 1, Colours.Syntax)..ParseResult(parsingContext, #word, Colours.String), true
            end
        end
    end
    return "", false
end

local function TalentModifier(parsingContext)
    local hasModifier = IsModifierSeparator(parsingContext)
    if hasModifier then
        local row = GetWord(parsingContext, 1)
        if not IsNumber(row) then return "", false end
        
        local separator = GetCharacter(parsingContext, 1 + #row)
        if separator ~= "/" then return "", false end
        
        local col = GetWord(parsingContext, 1 + #row + 1)
        if not IsNumber(col) then return "", false end

        return ParseResult(parsingContext, 1, Colours.Syntax)..
               ParseResult(parsingContext, #row, Colours.Number)..
               ParseResult(parsingContext, 1, Colours.Number)..
               ParseResult(parsingContext, #col, Colours.Number),
               true
    else
        return "", false
    end
end

-- Used for Spells or Item Types that might have spaces (e.g. "Two-Handed Axes")
local function MultiWordModifier(parsingContext)
    local hasModifier = IsModifierSeparator(parsingContext)
    if hasModifier then
        local text = ""
        local continue = true
        
        while continue do
            text = text .. GetWord(parsingContext, 1 + #text)
            local separator = GetCharacter(parsingContext, 1 + #text)
            
            if separator ~= " " and separator ~= "-" then
                continue = false
                if not separator or separator == "" then break end
            end
            
            if separator ~= "]" and separator ~= "," and separator ~= ":" then
                text = text .. separator
            end
        end

        if #text == 0 then return "", false end

        if IsNumber(text) then
            return ParseResult(parsingContext, 1, Colours.Syntax)..ParseResult(parsingContext, #text, Colours.Number), true
        else
            return ParseResult(parsingContext, 1, Colours.Syntax)..ParseResult(parsingContext, #text, Colours.String), true
        end
    else
        return "", false
    end
end

local function KnownModifier(parsingContext)
    return MultiWordModifier(parsingContext)
end

local Conditionals = {
    actionbar = NumberModifier, -- Fixed: actionbar takes a number [actionbar:1]
    advflyable = NoModifier,
    bar = NumberModifier,
    bonusbar = NumberModifier,
    btn = MouseButtonModifier,
    button = MouseButtonModifier,
    canexitvehicle = NoModifier,
    channeling = KnownModifier, -- Fixed: channeling accepts a spell name
    channelling = KnownModifier,
    combat = NoModifier,
    cursor = OptionalWordModifier,
    dead = NoModifier,
    equipped = MultiWordModifier, -- Fixed: item types can have spaces
    exists = NoModifier,
    extrabar = NumberModifier,
    flyable = NoModifier,
    flying = NoModifier,
    form = MultiNumberModifier,
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
    stance = MultiNumberModifier,
    stealth = NoModifier,
    swimming = NoModifier,
    talent = TalentModifier,
    unithasvehicleui = NoModifier,
    vehicleui = NoModifier,
    worn = MultiWordModifier, -- Fixed: item types can have spaces
    known = KnownModifier,
    noknown = KnownModifier,
    hasbuff = KnownModifier,    -- Note: hasbuff is NOT a valid retail secure conditional, but keeping for highlighting
    hastalent = TalentModifier, 
    facing = NoModifier
}

function GetMegaMacroParsingConditionsData()
    InitializeDependencies()
    return Conditionals
end