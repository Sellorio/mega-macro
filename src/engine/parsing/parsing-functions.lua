local ErrorHex = nil -- Cache for the error color

local function GetCharacter(parsingContext, offset)
    local index = parsingContext.Index + (offset or 0)
    if index > #parsingContext.Code then return nil end -- 12.0 Safety: Bounds check
    
    local result = string.sub(parsingContext.Code, index, index)
    return #result > 0 and result or nil
end

local function GetWord(parsingContext, offset)
    local index = parsingContext.Index + (offset or 0)
    local text = ""
    -- Optimization: Reuse a lightweight context instead of creating a new table every char
    local ctx = { Code = parsingContext.Code, Index = index } 
    local character = GetCharacter(ctx)
    
    while character and (string.match(character, "[a-z]") or string.match(character, "[A-Z]") or string.match(character, "[0-9]") or character == "_" or character == "/") do
        text = text..character
        index = index + 1
        ctx.Index = index
        character = GetCharacter(ctx)
    end
    return text
end

local function ParseResult(parsingContext, length, colour)
    if length == 0 then return "" end

    local text = string.sub(parsingContext.Code,
                            parsingContext.Index,
                            parsingContext.Index + length - 1)
    parsingContext.Index = parsingContext.Index + length

    -- 12.0 Update: Handle ColorMixin objects safely
    if type(colour) == "table" and colour.GetRGB then
        local r, g, b = colour:GetRGB()
        -- FIX: WoW expects |cAARRGGBB. We must prepend 'ff' for full opacity.
        colour = string.format("ff%02x%02x%02x", r*255, g*255, b*255)
    end

    -- Visualizing the 255 character limit for Native Macros
    if parsingContext.Index > (MegaMacroCodeMaxLengthForNative + 1) then
        -- Cache the error color once to improve parser performance
        if not ErrorHex and GetMegaMacroParsingColourData then
            ErrorHex = GetMegaMacroParsingColourData().Error
        end

        local overflow = parsingContext.Index - (MegaMacroCodeMaxLengthForNative + 1)
        
        -- Calculate split point safely
        local splitPoint = #text - overflow
        local valid = ""
        local excess = text

        if splitPoint > 0 then
            valid = text:sub(1, splitPoint)
            excess = text:sub(splitPoint + 1)
        elseif splitPoint == 0 then
            valid = ""
            excess = text
        else
            -- If the whole chunk is already past the limit (rare but possible)
            valid = ""
            excess = text
        end

        local errorColor = ErrorHex or "ffff0000" -- Fallback red
        return valid .. "|c"..errorColor..excess.."|r"
    else
        return colour and "|c"..colour..text.."|r" or text
    end
end

function GetMegaMacroParsingFunctions()
    return GetCharacter, GetWord, ParseResult
end