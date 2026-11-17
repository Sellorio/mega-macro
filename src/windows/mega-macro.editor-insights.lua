-- Live preview (fades the parts of a macro that wouldn't run right now) and hover
-- explanations for the macro editor.

local RefreshInterval = 0.15

-- What each condition means, worded for both the plain and the "no" version.
-- Each takes the text after the colon (if any) and whether it's the "no" version.

local function Simple(yes, no)
    return function(_, negated)
        return negated and no or yes
    end
end

-- "a", "a or b", "a, b or c"
local function JoinOr(items)
    if #items <= 1 then
        return items[1] or ""
    end
    return table.concat(items, ", ", 1, #items - 1) .. " or " .. items[#items]
end

local function SplitArg(arg)
    local items = {}
    for item in string.gmatch(arg or "", "[^/]+") do
        items[#items + 1] = (string.gsub(item, "^%s*(.-)%s*$", "%1"))
    end
    return items
end

local MouseButtonNames = {
    ["1"] = "left", LeftButton = "left", ["2"] = "right", RightButton = "right",
    ["3"] = "middle", MiddleButton = "middle", ["4"] = "fourth", Button4 = "fourth", ["5"] = "fifth", Button5 = "fifth",
}

local function Modifier(arg, negated)
    if not arg or arg == "" then
        return negated and "No modifier key (Shift, Ctrl or Alt) is held." or "A modifier key (Shift, Ctrl or Alt) is held."
    end
    local keys = {}
    for _, key in ipairs(SplitArg(arg)) do
        -- shiftctrl means both together
        local parts = {}
        local lower = string.lower(key)
        for _, name in ipairs({ "Shift", "Ctrl", "Alt" }) do
            if string.find(lower, string.lower(name), 1, true) then
                parts[#parts + 1] = name
            end
        end
        keys[#keys + 1] = #parts > 0 and table.concat(parts, "+") or key
    end
    if negated then
        if #keys == 1 then
            return keys[1] .. " isn't held."
        elseif #keys == 2 then
            return "Neither " .. keys[1] .. " nor " .. keys[2] .. " is held."
        end
        return "None of " .. JoinOr(keys) .. " is held."
    end
    return JoinOr(keys) .. " is held."
end

local function WithArg(yes, no, yesWithout, noWithout)
    return function(arg, negated)
        if arg and arg ~= "" then
            return string.format(negated and no or yes, JoinOr(SplitArg(arg)))
        end
        return negated and noWithout or yesWithout
    end
end

local ConditionText = {
    actionbar = WithArg("Action bar page %s is showing.", "Action bar page %s isn't showing."),
    advflyable = Simple("You can skyride here.", "You can't skyride here."),
    bonusbar = WithArg("Bonus action bar %s is showing.", "Bonus action bar %s isn't showing.",
        "A bonus action bar (like a form's bar) is showing.", "No bonus action bar is showing."),
    button = function(arg, negated)
        local names = {}
        for _, item in ipairs(SplitArg(arg)) do
            names[#names + 1] = MouseButtonNames[item] or item
        end
        return string.format(negated and "You don't click it with the %s mouse button." or "You click it with the %s mouse button.", JoinOr(names))
    end,
    canexitvehicle = Simple("You're in a vehicle you can leave.", "You're not in a vehicle you can leave."),
    channeling = WithArg("You're channelling %s.", "You're not channelling %s.", "You're channelling a spell.", "You're not channelling a spell."),
    combat = Simple("You're in combat.", "You're not in combat."),
    cursor = Simple("You're holding something on your cursor.", "Your cursor is empty."),
    dead = Simple("The target is dead.", "The target isn't dead."),
    equipped = WithArg("You have %s equipped.", "You don't have %s equipped."),
    exists = Simple("There is a target.", "There's no target."),
    extrabar = Simple("The extra action button is showing.", "The extra action button isn't showing."),
    facing = Simple("You're facing the target.", "You're not facing the target."),
    flyable = Simple("You can fly here.", "You can't fly here."),
    flying = Simple("You're flying.", "You're not flying."),
    group = WithArg("You're in a %s.", "You're not in a %s.", "You're in a group.", "You're not in a group."),
    harm = Simple("The target is an enemy you can attack.", "The target isn't an enemy you can attack."),
    hasbuff = WithArg("The target has %s.", "The target doesn't have %s."),
    help = Simple("The target is someone you can help, like a friendly player.", "The target isn't someone you can help."),
    indoors = Simple("You're indoors.", "You're not indoors."),
    known = WithArg("You know %s.", "You don't know %s."),
    modifier = Modifier,
    mounted = Simple("You're mounted.", "You're not mounted."),
    outdoors = Simple("You're outdoors.", "You're not outdoors."),
    overridebar = Simple("A vehicle or quest action bar is showing.", "No vehicle or quest action bar is showing."),
    party = Simple("The target is in your party.", "The target isn't in your party."),
    pet = WithArg("Your %s is out.", "Your %s isn't out.", "You have a pet out.", "You don't have a pet out."),
    petbattle = Simple("You're in a pet battle.", "You're not in a pet battle."),
    possessbar = Simple("You're controlling another creature.", "You're not controlling another creature."),
    pvptalent = WithArg("You have PvP talent %s.", "You don't have PvP talent %s."),
    raid = Simple("The target is in your raid.", "The target isn't in your raid."),
    stealth = Simple("You're stealthed.", "You're not stealthed."),
    swimming = Simple("You're swimming.", "You're not swimming."),
    talent = WithArg("You have talent %s.", "You don't have talent %s."),
    unithasvehicleui = Simple("The target is in a vehicle.", "The target isn't in a vehicle."),
    vehicleui = Simple("You're in a vehicle.", "You're not in a vehicle."),
}
ConditionText.bar = ConditionText.actionbar
ConditionText.btn = ConditionText.button
ConditionText.channelling = ConditionText.channeling
ConditionText.worn = ConditionText.equipped
ConditionText.mod = ConditionText.modifier
ConditionText.hastalent = ConditionText.talent
ConditionText.noknown = function(arg, negated) return ConditionText.known(arg, not negated) end

local UnitHelp = {
    player = "yourself",
    target = "your current target",
    focus = "your focus target",
    mouseover = "the unit under your mouse pointer, including on unit frames",
    cursor = "the ground under your mouse pointer, for spells you place on the ground",
    none = "no one. The spell is cast without a target",
    pet = "your pet",
    vehicle = "your vehicle",
}

-- For "true right now for ..."
local ShortUnitNames = {
    player = "you",
    mouseover = "the unit under your mouse",
    cursor = "the ground under your mouse",
}

local IndexedUnitHelp = {
    { "partypet", "the pet of party member %s" },
    { "raidpet", "the pet of raid member %s" },
    { "party", "party member %s" },
    { "raid", "raid member %s" },
    { "arena", "arena enemy %s" },
    { "boss", "boss %s" },
}

local CommandHelp = {
    cast = "Casts the first spell (or uses the item) whose conditions are true.",
    use = "Uses the first item (or casts the spell) whose conditions are true.",
    castsequence = "Casts the spells in the list one after another, one per press.",
    castrandom = "Casts a random spell from the list.",
    userandom = "Uses a random item from the list.",
    stopmacro = "Stops the macro here if its conditions are true. Lines after it don't run.",
    cancelaura = "Removes this buff from you.",
    cancelform = "Leaves your current form or stance.",
    startattack = "Starts auto attacking.",
    stopattack = "Stops auto attacking.",
    stopcasting = "Stops the spell you're casting.",
    target = "Targets this unit or name.",
    targetenemy = "Targets the nearest enemy.",
    targetfriend = "Targets the nearest friend.",
    cleartarget = "Clears your target.",
    focus = "Sets your focus target.",
    clearfocus = "Clears your focus target.",
    assist = "Targets what this unit is targeting.",
    petattack = "Sends your pet to attack.",
    petfollow = "Calls your pet back to follow you.",
    equip = "Equips this item.",
    equipset = "Equips this equipment set.",
    click = "Clicks this button, as if you pressed it.",
    dismount = "Dismounts you.",
    worldmarker = "Places this world marker.",
}

local Helpers = {}

local function SpellNameFromId(spellId)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellId)
    end
end

function Helpers.Forms()
    local forms = {}
    local count = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    for i = 1, count do
        local _, active, _, spellId = GetShapeshiftFormInfo(i)
        forms[i] = { Name = spellId and SpellNameFromId(spellId) or ("Form " .. i), Active = active }
    end
    return forms
end

function Helpers.Specs()
    local specs = {}
    local getCount = GetNumSpecializations
    local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    local getCurrent = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    if not getCount or not getInfo then
        return specs
    end
    local okCount, count = pcall(getCount)
    local current = getCurrent and select(2, pcall(getCurrent))
    for i = 1, okCount and count or 0 do
        local ok, _, name = pcall(getInfo, i)
        if ok and name then
            specs[i] = { Name = name, Active = i == current }
        end
    end
    return specs
end

local function DescribeUnit(unit)
    if UnitHelp[unit] then
        return UnitHelp[unit]
    end
    for _, entry in ipairs(IndexedUnitHelp) do
        local number = string.match(unit, "^" .. entry[1] .. "(%d+)$")
        if number then
            return string.format(entry[2], number)
        end
    end
    -- Things like targettarget or focustarget
    local base = string.match(unit, "^(%a-)target$")
    if base and base ~= "" then
        return "the target of " .. (UnitHelp[base] or base)
    end
end

local function AddState(tooltip, passes, trueText, falseText)
    if passes == true then
        tooltip:AddLine(trueText, 0.25, 1, 0.25, true)
    elseif passes == false then
        tooltip:AddLine(falseText, 1, 0.35, 0.35, true)
    end
end

-- Words the rule as a rule ("True when you're in combat."), so it isn't read as a
-- statement about right now. Key names keep their capital.
local function TrueWhen(sentence)
    if not string.match(sentence, "^Shift") and not string.match(sentence, "^Ctrl") and not string.match(sentence, "^Alt") then
        sentence = string.gsub(sentence, "^%u", string.lower)
    end
    return "True when " .. sentence
end

local function SelectedNumbers(arg)
    local selected = {}
    for number in string.gmatch(arg or "", "%d+") do
        selected[tonumber(number)] = true
    end
    return selected
end

-- Lists this character's forms (or specs) with the ones in the macro highlighted
local function AddList(tooltip, entries, selected, zeroName)
    local function Add(index, name, active)
        local text = index .. ": " .. name .. (active and "  (current)" or "")
        if selected[index] then
            tooltip:AddLine(text, 1, 1, 1)
        else
            tooltip:AddLine(text, 0.6, 0.6, 0.6)
        end
    end

    if zeroName then
        local anyActive = false
        for _, entry in ipairs(entries) do
            anyActive = anyActive or entry.Active
        end
        Add(0, zeroName, not anyActive)
    end
    for index, entry in ipairs(entries) do
        Add(index, entry.Name, entry.Active)
    end
end

-- stance:/form: (zeroName set) and spec:, named the way this character has them
local function ShowNumbered(tooltip, token, entries, noun, zeroName)
    local text

    if not token.Arg or token.Arg == "" then
        if zeroName then
            text = token.Negated and "You're not in any " .. noun .. "." or "You're in a " .. noun .. "."
        else
            text = "You have a " .. noun .. "."
        end
    else
        local names, missing = {}, {}
        for _, item in ipairs(SplitArg(token.Arg)) do
            local number = tonumber(item)
            if number == 0 and zeroName then
                names[#names + 1] = string.lower(zeroName)
            elseif number and entries[number] then
                names[#names + 1] = entries[number].Name
            else
                names[#names + 1] = noun .. " " .. item
                missing[#missing + 1] = item
            end
        end

        text = "You're " .. (token.Negated and "not " or "") .. (zeroName and "in " or "using ") .. JoinOr(names) .. "."
        if #missing > 0 then
            text = text .. " This character doesn't have a " .. noun .. " " .. JoinOr(missing) .. "."
        end
    end
    tooltip:AddLine(TrueWhen(text), 1, 0.82, 0, true)

    if #entries > 0 then
        tooltip:AddLine(" ")
        AddList(tooltip, entries, SelectedNumbers(token.Arg), zeroName)
    elseif zeroName then
        tooltip:AddLine("This character has no forms or stances.", 0.6, 0.6, 0.6, true)
    end
end

local function ShowCondition(tooltip, token)
    local name = token.Name
    tooltip:AddLine(token.Text, 1, 1, 1)

    if not token.Known then
        tooltip:AddLine("This isn't a macro condition. Check the spelling.", 1, 0.35, 0.35, true)
        return
    end

    if name == "stance" or name == "form" then
        ShowNumbered(tooltip, token, Helpers.Forms(), name, "No " .. name)
    elseif name == "spec" then
        ShowNumbered(tooltip, token, Helpers.Specs(), "spec")
    elseif ConditionText[name] then
        tooltip:AddLine(TrueWhen(ConditionText[name](token.Arg, token.Negated)), 1, 0.82, 0, true)
    end

    local unit = token.Group and token.Group.Target and token.Group.Target.Unit
    local checkedOn = unit and (ShortUnitNames[unit] or DescribeUnit(unit))
    tooltip:AddLine(" ")
    AddState(tooltip, token.Passes,
        "True right now" .. (checkedOn and (" for " .. checkedOn) or ""),
        "False right now" .. (checkedOn and (" for " .. checkedOn) or ""))
end

local function ShowTarget(tooltip, token)
    tooltip:AddLine(token.Text, 1, 1, 1)
    local description = DescribeUnit(token.Unit)
    if description then
        tooltip:AddLine("Acts on " .. description .. ".", 1, 0.82, 0, true)
    else
        tooltip:AddLine("Acts on the player or unit named " .. token.Unit .. ".", 1, 0.82, 0, true)
    end
    if UnitExists and description and token.Unit ~= "cursor" and token.Unit ~= "none" then
        local ok, exists = pcall(UnitExists, token.Unit)
        if ok and exists ~= nil then
            AddState(tooltip, exists and true or false, "There is one right now", "There isn't one right now")
        end
    end
end

local SlotNames = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulder", [4] = "Shirt", [5] = "Chest", [6] = "Waist", [7] = "Legs",
    [8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Ring 1", [12] = "Ring 2", [13] = "Trinket 1",
    [14] = "Trinket 2", [15] = "Back", [16] = "Main hand", [17] = "Off hand", [19] = "Tabard",
}

-- Shows the spell or item's own tooltip. Returns false if the name doesn't match anything.
local function ShowName(tooltip, token)
    local text = token.Text
    local slot = tonumber(text)

    if slot then
        if GetInventoryItemID and GetInventoryItemID("player", slot) then
            tooltip:SetInventoryItem("player", slot)
        else
            tooltip:AddLine((SlotNames[slot] or ("Slot " .. slot)), 1, 1, 1)
            tooltip:AddLine("Uses whatever is equipped in this slot. It's empty right now.", 1, 0.82, 0, true)
        end
        return true
    end

    local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(text)
    if spellInfo and spellInfo.spellID then
        tooltip:SetSpellByID(spellInfo.spellID)
        return true
    end

    local itemId = C_Item and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(text)
    if itemId then
        tooltip:SetItemByID(itemId)
        return true
    end

    tooltip:AddLine(text, 1, 1, 1)
    tooltip:AddLine("This character doesn't know a spell or have an item called this. Check the spelling.", 1, 0.35, 0.35, true)
    return true
end

local function AddClauseState(tooltip, clause)
    if not clause or clause.Line.Unknown then
        return
    end
    tooltip:AddLine(" ")
    if clause.Line.Stopped then
        tooltip:AddLine("Not used right now: an earlier /stopmacro ends the macro first.", 1, 0.35, 0.35, true)
    elseif clause.Used and clause.Line.Empty then
        tooltip:AddLine("Used right now, but it names nothing, so nothing happens.", 1, 0.35, 0.35, true)
    elseif clause.Used then
        tooltip:AddLine("Used right now", 0.25, 1, 0.25)
    elseif clause.Passes then
        tooltip:AddLine("Not used right now: an earlier option on this line is used instead.", 1, 0.35, 0.35, true)
    else
        tooltip:AddLine("Not used right now: its conditions are false.", 1, 0.35, 0.35, true)
    end
end

local function ShowCommand(tooltip, token)
    tooltip:AddLine("/" .. token.Name, 1, 1, 1)
    local help = CommandHelp[token.Name]
    if help then
        tooltip:AddLine(help, 1, 0.82, 0, true)
    end
    local line = token.Line
    if line.Stopped then
        tooltip:AddLine(" ")
        tooltip:AddLine("Doesn't run right now: an earlier /stopmacro ends the macro first.", 1, 0.35, 0.35, true)
    elseif #line.Clauses > 0 and not line.Unknown and not line.Winner then
        tooltip:AddLine(" ")
        tooltip:AddLine("Does nothing right now: none of its conditions are true.", 1, 0.35, 0.35, true)
    elseif not line.Unknown and line.Empty then
        tooltip:AddLine(" ")
        tooltip:AddLine("Does nothing right now: the option in use is empty.", 1, 0.35, 0.35, true)
    end
    return help ~= nil or line.Stopped or (#line.Clauses > 0 and not line.Winner) or line.Empty
end

local function ShowDirective(tooltip, token)
    tooltip:AddLine("#" .. token.Name, 1, 1, 1)
    tooltip:AddLine("Picks the icon and tooltip shown for this macro on your action bars.", 1, 0.82, 0, true)
end

-- Fills the tooltip for a token. Returns false when there's nothing worth showing.
function MegaMacroInsights.FillTooltip(tooltip, token)
    if token.Kind == "condition" then
        ShowCondition(tooltip, token)
    elseif token.Kind == "target" then
        ShowTarget(tooltip, token)
    elseif token.Kind == "name" then
        ShowName(tooltip, token)
        AddClauseState(tooltip, token.Clause)
    elseif token.Kind == "command" then
        return ShowCommand(tooltip, token)
    elseif token.Kind == "directive" then
        ShowDirective(tooltip, token)
    else
        return false
    end
    return true
end

-- Changes whenever the "right now" parts of a token's tooltip would change
function MegaMacroInsights.TooltipState(token)
    local state = {}
    local function Add(value) state[#state + 1] = tostring(value) end

    if token.Kind == "condition" then
        Add(token.Passes)
        if token.Name == "stance" or token.Name == "form" then
            Add(GetShapeshiftForm and GetShapeshiftForm())
        end
    elseif token.Kind == "target" then
        local ok, exists = pcall(UnitExists, token.Unit)
        Add(ok and exists)
    elseif token.Kind == "name" then
        local clause = token.Clause
        Add(clause.Used) Add(clause.Passes) Add(clause.Line.Stopped) Add(clause.Line.Unknown)
    elseif token.Kind == "command" then
        Add(token.Line.Stopped) Add(token.Line.Winner ~= nil) Add(token.Line.Unknown) Add(token.Line.Empty)
    end

    return table.concat(state, ",")
end

---------------------------------------------------------------------------------------------------
-- Editor wiring

local CurrentScan
local LastSignature
local Measure
local HoverToken
local HoverState
local Elapsed = 0

local function IsLivePreviewOn()
    return not MegaMacroConfig or MegaMacroConfig.LivePreview ~= false
end

local function IsHoverHelpOn()
    return not MegaMacroConfig or MegaMacroConfig.HoverHelp ~= false
end

local function Render(force)
    local text = MegaMacro_FrameText:GetText() or ""
    local scan = CurrentScan
    if not scan or scan.Code ~= text then
        scan = MegaMacroInsights.Scan(text)
    end
    local dim, signature = MegaMacroInsights.Evaluate(scan)

    if not IsLivePreviewOn() then
        dim, signature = nil, ""
    end

    CurrentScan = scan
    if force or signature ~= LastSignature then
        LastSignature = signature
        MegaMacro_FormattedFrameText:SetText(MegaMacroParser.Parse(text, dim))
    end
end

-- Works out which character of the macro is under the mouse. Lines are laid out the
-- same way the edit box does it: wrapped at spaces when they get too wide.
local function GetMeasure()
    if not Measure then
        Measure = MegaMacro_FrameText:CreateFontString(nil, "BACKGROUND")
        Measure:SetAlpha(0)
    end
    Measure:SetFontObject(MegaMacro_FrameText:GetFontObject() or GameFontHighlightSmall)
    return Measure
end

local function Width(text)
    local measure = GetMeasure()
    measure:SetText((string.gsub(text, "|", "!")))
    return measure.GetUnboundedStringWidth and measure:GetUnboundedStringWidth() or measure:GetStringWidth()
end

local function LineStep()
    local measure = GetMeasure()
    measure:SetWidth(1000)
    measure:SetText("A")
    local one = measure:GetStringHeight()
    measure:SetText("A\nA")
    local two = measure:GetStringHeight()
    measure:SetWidth(0)
    local step = two - one
    return step > 0 and step or one
end

-- Splits the code into the rows the edit box shows: { S = first char, E = last char }
local function VisualRows(code, maxWidth)
    local rows = {}
    local s = 1
    local length = #code

    while s <= length + 1 do
        local newline = string.find(code, "\n", s, true)
        local e = newline and newline - 1 or length
        local rowStart = s

        while Width(string.sub(code, rowStart, e)) > maxWidth do
            -- longest piece that fits, broken after a space where possible
            local fit = rowStart
            while fit < e and Width(string.sub(code, rowStart, fit + 1)) <= maxWidth do
                fit = fit + 1
            end
            local breakAt = fit
            for i = fit, rowStart, -1 do
                if string.sub(code, i, i) == " " then
                    breakAt = i
                    break
                end
            end
            table.insert(rows, { S = rowStart, E = breakAt })
            rowStart = breakAt + 1
        end

        table.insert(rows, { S = rowStart, E = e })
        if not newline then
            break
        end
        s = newline + 1
    end

    return rows
end

local RowsCache = { Code = nil, Width = nil, Rows = nil, Step = nil }
local MouseCache = { X = nil, Y = nil, Code = nil, Index = nil }

local function CharacterUnderMouse()
    local box = MegaMacro_FrameText
    local code = box:GetText() or ""
    if code == "" then
        return nil
    end

    local left, top = box:GetLeft(), box:GetTop()
    if not left or not top then
        return nil
    end

    local scale = box:GetEffectiveScale()
    local x, y = GetCursorPosition()
    x, y = x / scale - left, top - y / scale

    if MouseCache.X == x and MouseCache.Y == y and MouseCache.Code == code then
        return MouseCache.Index
    end
    MouseCache.X, MouseCache.Y, MouseCache.Code, MouseCache.Index = x, y, code, nil

    local width = box:GetWidth()
    if RowsCache.Code ~= code or RowsCache.Width ~= width then
        RowsCache.Code = code
        RowsCache.Width = width
        RowsCache.Step = LineStep()
        RowsCache.Rows = VisualRows(code, width)
    end

    local row = RowsCache.Rows[math.floor(y / RowsCache.Step) + 1]
    if not row or x < 0 or row.E < row.S then
        return nil
    end

    for i = row.S, row.E do
        if x < Width(string.sub(code, row.S, i)) then
            MouseCache.Index = i
            return i
        end
    end
    return nil
end

local function HideHover()
    if HoverToken and GameTooltip:GetOwner() == MegaMacro_FrameScrollFrame then
        GameTooltip:Hide()
    end
    HoverToken = nil
end

local function UpdateHover()
    if not IsHoverHelpOn() or not MegaMacro_FrameScrollFrame:IsMouseOver() or not CurrentScan then
        HideHover()
        return
    end

    local ok, index = pcall(CharacterUnderMouse)
    local token = ok and MegaMacroInsights.TokenAt(CurrentScan, index) or nil

    if not token then
        HideHover()
        return
    end

    -- Same thing as before and nothing about it changed (the scan is rebuilt often, so compare by position)
    local state = MegaMacroInsights.TooltipState(token)
    if HoverToken and HoverToken.S == token.S and HoverToken.E == token.E and HoverToken.Kind == token.Kind
        and HoverState == state and GameTooltip:IsShown() and GameTooltip:GetOwner() == MegaMacro_FrameScrollFrame then
        return
    end

    HoverToken = token
    HoverState = state
    GameTooltip:SetOwner(MegaMacro_FrameScrollFrame, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    if MegaMacroInsights.FillTooltip(GameTooltip, token) then
        GameTooltip:Show()
    else
        GameTooltip:Hide()
    end
end

MegaMacroEditorInsights = {}

-- Called when the macro text changes
function MegaMacroEditorInsights.Refresh()
    Render(true)
    HoverToken = nil
end

function MegaMacroEditorInsights.OnUpdate(elapsed)
    Elapsed = Elapsed + elapsed
    if Elapsed < RefreshInterval then
        return
    end
    Elapsed = 0

    if IsLivePreviewOn() or IsHoverHelpOn() then
        Render(false)
    end
    UpdateHover()
end

-- A child of the edit box, so it only runs while the editor is on screen
local Updater = CreateFrame("Frame", nil, MegaMacro_FrameText)
Updater:SetScript("OnUpdate", function(_, elapsed)
    MegaMacroEditorInsights.OnUpdate(elapsed)
end)
Updater:SetScript("OnHide", HideHover)
