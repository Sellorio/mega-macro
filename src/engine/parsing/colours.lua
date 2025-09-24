local function StripAlpha(hexStr)
    -- Remove the leading “ff” (full opacity) – the UI default is opaque.
    return hexStr:gsub("^ff", "")
end

local function GetColorFromHex(hexStr)
    -- 11.2 API: CreateColorFromHexString expects a 6‑digit hex string.
    return CreateColorFromHexString(StripAlpha(hexStr))
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