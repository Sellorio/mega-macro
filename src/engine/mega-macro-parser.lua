-- Existing command collection -------------------------------------------------
local Commands = {
    "cast",
    "use",
    "castsequence",
    "stopmacro",
    "cancelaura",
    "equip",
    "equipset",
    "userandom",
    "run"
}

-- 1️⃣  Pull in all slash commands that actually start with '/'.
-- 12.0 Optimization: Only check keys starting with "SLASH_" to avoid iterating the whole environment unnecessarily
for globalName, command in pairs(_G) do
    if type(globalName) == "string" and string.sub(globalName, 1, 6) == "SLASH_" then
        if type(command) == "string" and string.sub(command, 1, 1) == "/" then
            table.insert(Commands, string.sub(command, 2))
        elseif type(command) == "function" then
            -- Some newer addons map directly to functions; ignore for text parsing
        end
    end
end

-- 2️⃣  Gather emotes – support both the legacy and the new naming scheme.
for i = 1, 999 do
    local legacy   = _G["EMOTE"..i.."_TOKEN"]
    local modern   = _G["EMOTE_TOKEN_"..i]   -- new pattern in 11.2/12.0
    local emoteTok = legacy or modern
    if not emoteTok then break end
    table.insert(Commands, string.lower(emoteTok))
end

-- Ensure we have the parsing data functions available
local Colours = nil
local Conditions = nil
local GetCharacter, GetWord, ParseResult = nil, nil, nil

-- 12.0 Safety: Lazy load these in case the load order changed
local function InitializeParsingData()
    if not Colours and GetMegaMacroParsingColourData then
        Colours = GetMegaMacroParsingColourData()
    end
    if not Conditions and GetMegaMacroParsingConditionsData then
        Conditions = GetMegaMacroParsingConditionsData()
    end
    if not GetCharacter and GetMegaMacroParsingFunctions then
        GetCharacter, GetWord, ParseResult = GetMegaMacroParsingFunctions()
    end
end

local ConditionalEnclosed = nil
local ConditionalBroken = nil

local function UpdateConstants()
    if Colours then
        ConditionalEnclosed = "|c"..Colours.Syntax.."[|r"
        ConditionalBroken = "|c"..Colours.Error.."[|r"
    end
end

local function IsEndOfLine(parsingContext, offset)
    local character = GetCharacter(parsingContext, offset)
    return not character or character == '\n'
end

local function ParseWhiteSpace(parsingContext)
    local result = ""
    local character = GetCharacter(parsingContext)

    if not character then
        return "", false
    end

    while character == " " or character == "\t" do
        result = result..character
        parsingContext.Index = parsingContext.Index + 1
        character = GetCharacter(parsingContext)
    end

    return result, true
end

local function ParseComment(parsingContext)
    local character = GetCharacter(parsingContext)
    local offset = 0

    if character ~= "#" then
        return "", false
    end

    while character and character ~= "\n" do
        offset = offset + 1
        character = GetCharacter(parsingContext, offset)
    end

    if character == '\n' then
        offset = offset + 1
    end

    return ParseResult(parsingContext, offset, Colours.Comment), true
end

local function ParseRestOfLineAsError(parsingContext)
    local result = ""
    local length = 0
    while not IsEndOfLine(parsingContext, length) do
        length = length + 1
    end
    result = result..ParseResult(parsingContext, length, Colours.Error)
    return result
end

local function IsIndexedUnitId(unitId, unitType, maxIndex)
    if string.sub(unitId, 1, #unitType) == unitType then
        local index = tonumber(string.sub(unitId, #unitType + 1))
        if index and index > 0 and index <= maxIndex then
            return true
        end
    end

    return false
end

local function IsValidUnitId(unitId)
    return
        IsIndexedUnitId(unitId, "arena", 5) or
        IsIndexedUnitId(unitId, "boss", 5) or -- Increased to 5 for modern raids
        unitId == "focus" or
        unitId == "mouseover" or
        unitId == "cursor" or
        unitId == "none" or
        -- 12.0: Added modern Soft Target units
        unitId == "softenemy" or
        unitId == "softfriend" or
        unitId == "softinteract" or
        IsIndexedUnitId(unitId, "party", 4) or
        IsIndexedUnitId(unitId, "partypet", 4) or
        unitId == "pet" or
        unitId == "player" or
        IsIndexedUnitId(unitId, "raid", 40) or
        IsIndexedUnitId(unitId, "raidpet", 40) or
        unitId == "target" or
        unitId == "vehicle"
end

local function ParseTarget(parsingContext)
    local result = ""
    local character = GetCharacter(parsingContext)
    local indexBeforeTarget = parsingContext.Index

    if character == '@' then
        result = ParseResult(parsingContext, 1, Colours.Target)
    elseif GetWord(parsingContext) == "target" then
        result = ParseResult(parsingContext, 6, Colours.Target)
        result = result..ParseWhiteSpace(parsingContext)

        character = GetCharacter(parsingContext)

        if character ~= '=' then
            parsingContext.Index = indexBeforeTarget
            return "", false
        end

        result = result..ParseResult(parsingContext, 1, Colours.Target)
        result = result..ParseWhiteSpace(parsingContext)
    else
        return "", false
    end

    local target = GetWord(parsingContext)

    if IsValidUnitId(target) then
        return
            result..ParseResult(parsingContext, #target, Colours.Target),
            true
    else
        parsingContext.Index = indexBeforeTarget
        return "", false
    end
end

local function ParseConditionalPart(parsingContext)
    local result = ParseWhiteSpace(parsingContext)

    local newResult, success = ParseTarget(parsingContext)

    if success then
        result = result..newResult
    else
        if GetCharacter(parsingContext) == 'n' and GetCharacter(parsingContext, 1) == 'o' then
            result = result..ParseResult(parsingContext, 2, Colours.Condition)
        end

        result = result..ParseWhiteSpace(parsingContext)

        local word = GetWord(parsingContext)
        local modifierParseFunction = Conditions[word]

        if not modifierParseFunction then
            result = result..ParseResult(parsingContext, #word, Colours.Error)
        else
            local conditionCode = ParseResult(parsingContext, #word, Colours.Condition)
            newResult, success = modifierParseFunction(parsingContext)

            if success then
                result = result..conditionCode..newResult
            else
                parsingContext.Index = parsingContext.Index - #word
                result = result..ParseResult(parsingContext, #word, Colours.Error)
            end
        end
    end

    result = result..ParseWhiteSpace(parsingContext)

    local character = GetCharacter(parsingContext)
    while character and character ~= ',' and character ~= ']' and character ~= '\n' do
        result = result..ParseResult(parsingContext, 1, Colours.Error)
        character = GetCharacter(parsingContext)
    end

    return result
end

local function ParseConditional(parsingContext)
    local character = GetCharacter(parsingContext)

    if character ~= '[' then
        return "", false
    end

    parsingContext.Index = parsingContext.Index + 1

    local result = ""

    local newResult = ParseConditionalPart(parsingContext)
    while true do
        result = result..newResult
        character = GetCharacter(parsingContext)

        if IsEndOfLine(parsingContext) then
            return ConditionalBroken..result, true
        end
        if character == ']' then
            return ConditionalEnclosed..result..ParseResult(parsingContext, 1, Colours.Syntax), true
        end
        if character ~= ',' then
            return ConditionalBroken..result..ParseRestOfLineAsError(), true
        end

        result = result..ParseResult(parsingContext, 1, Colours.Syntax)

        newResult = ParseConditionalPart(parsingContext)
    end

    return ConditionalBroken..result
end

local function ParseCommand(parsingContext)
    local character = GetCharacter(parsingContext)

    if character ~= '/' then
        return "", false
    end

    local preCommandIndex = parsingContext.Index
    local result = ParseResult(parsingContext, 1, Colours.Syntax)

    local commandName = GetWord(parsingContext)

    if #commandName == 0 then
        parsingContext.Index = preCommandIndex
        return "", false
    end

    local commandFound = false
    -- Optimized: No change needed here, Commands table is pre-filled efficiently now
    for i=1, #Commands do
        if commandName == Commands[i] then
            commandFound = true
            break
        end
    end

    if not commandFound then
        parsingContext.Index = preCommandIndex
        return "", false
    end

    result = result..ParseResult(parsingContext, #commandName, Colours.Command)

    if IsEndOfLine(parsingContext) then
        return result, true
    end

    while not IsEndOfLine(parsingContext) do
        result = result..ParseWhiteSpace(parsingContext)

        local newResult, success = ParseConditional(parsingContext)
        while success do
            result = result..newResult..ParseWhiteSpace(parsingContext)
            newResult, success = ParseConditional(parsingContext)
        end

        newResult, success = ParseComment(parsingContext)

        if success then
            return result..newResult
        end

        local bodyPartLength = 0
        character = GetCharacter(parsingContext)
        while not IsEndOfLine(parsingContext) and character ~= ";" do
            bodyPartLength = bodyPartLength + 1
            parsingContext.Index = parsingContext.Index + 1
            character = GetCharacter(parsingContext)
        end

        if bodyPartLength > 0 then
            parsingContext.Index = parsingContext.Index - bodyPartLength
            result = result..ParseResult(parsingContext, bodyPartLength, Colours.CommandContent)..ParseWhiteSpace(parsingContext)
        end

        if character == ";" then
            result = result..ParseResult(parsingContext, 1, Colours.Syntax)
        end
    end

    return result
end

function ParseLine(parsingContext)
    local result = ""
    local newResult, success = ParseWhiteSpace(parsingContext)

    if not success then
        return "", false
    end

    result = result..newResult

    if IsEndOfLine(parsingContext) then
        result = result..ParseResult(parsingContext, 1, Colours.Default)
        return result, true
    end

    newResult, success = ParseComment(parsingContext)

    if success then
        return result..newResult, true
    end

    newResult, success = ParseCommand(parsingContext)
    result = result..newResult..ParseRestOfLineAsError(parsingContext)

    return result, true
end

MegaMacroParser = {}

function MegaMacroParser.Parse(code)
    -- Lazy initialization of external dependencies
    InitializeParsingData()
    UpdateConstants()

    if not Colours or not GetCharacter then 
        return code -- Fallback if parsing dependencies missing
    end

    local result = ""
    local parsingContext = { Code = code, Index = 1 }

    local newResult, notEndOfCode = ParseLine(parsingContext)
    while notEndOfCode do
        result = result..newResult
        newResult, notEndOfCode = ParseLine(parsingContext)
    end

    return result
end