local function GetColorFromHex(hexStr)
    -- 12.0 API: CreateColorFromHexString handles 8-digit (ARGB) or 6-digit (RGB) strings natively.
    -- We no longer need to strip the alpha channel manually.
    if CreateColorFromHexString then
        return CreateColorFromHexString(hexStr)
    end
    
    -- Fail-safe fallback if the global is missing
    return CreateColor(1, 1, 1, 1)
end

function GetMegaMacroParsingColourData()
    return {
        String          = "ffff9900",
        Number          = "ffff9900",
        Emote           = "ffeedd82",
        Command         = "ff33ddff",
        Target          = "ffffd700",
        Condition       = "ffff9900",
        Default         = "ffffffff",
        Error           = "ffff4444",
        CommandContent  = "ffeeeeee",
        Syntax          = "ff33ddff",
        Comment         = "ff44ff44",

        -- Optional convenience: callers that want a Color object can use this.
        GetColor = GetColorFromHex
    }
end