-- Works out what each part of a macro means and whether it would run right now.
-- The editor uses this to fade the parts that wouldn't run and to explain things on hover.
-- Positions are character indexes into the macro code (1-based, inclusive).

local Conditions = GetMegaMacroParsingConditionsData()

-- Commands whose text can hold [conditions] and ; alternatives
local OptionCommands = {}
for _, name in ipairs({
    "cast", "use", "castsequence", "castrandom", "userandom", "stopmacro", "cancelaura", "cancelform",
    "startattack", "stopattack", "stopcasting", "stopspelltarget", "spellstopcasting", "target", "tar",
    "targetenemy", "targetfriend", "targetenemyplayer", "targetfriendplayer", "targetparty", "targetraid",
    "targetlasttarget", "targetlastenemy", "targetlastfriend", "targetexact", "cleartarget", "focus",
    "clearfocus", "assist", "petattack", "petassist", "petfollow", "petmoveto", "petstay", "petpassive",
    "petdefensive", "petaggressive", "petdismiss", "petautocaston", "petautocastoff", "petautocasttoggle",
    "equip", "eq", "equipslot", "equipset", "click", "dismount", "leavevehicle", "worldmarker",
    "clearworldmarker", "summonpet", "randompet", "randomfavoritepet", "usetalents", "changeactionbar",
    "swapactionbar", "cancelqueuedspell",
}) do
    OptionCommands[name] = true
end

-- Commands whose text after the conditions is a spell or item (or a list of them)
local SingleNameCommands = { cast = true, use = true, cancelaura = true }
local ListNameCommands = { castsequence = true, castrandom = true, userandom = true }

local function TrimRange(code, s, e)
    while s <= e and string.find(string.sub(code, s, s), "%s") do s = s + 1 end
    while e >= s and string.find(string.sub(code, e, e), "%s") do e = e - 1 end
    return s, e
end

local function AddToken(scan, token)
    table.insert(scan.Tokens, token)
    return token
end

local function ParseCondition(scan, group, code, s, e)
    s, e = TrimRange(code, s, e)
    if s > e then
        return
    end

    local text = string.sub(code, s, e)
    local unit = string.match(text, "^@%s*(.-)$") or string.match(text, "^[Tt][Aa][Rr][Gg][Ee][Tt]%s*=%s*(.-)$")

    if unit then
        group.Target = AddToken(scan, { Kind = "target", S = s, E = e, Text = text, Unit = string.lower(unit), Group = group })
        return
    end

    local word = string.match(text, "^([%a_]+)") or ""
    local name = string.lower(word)
    local negated = false

    if not Conditions[name] and string.sub(name, 1, 2) == "no" and Conditions[string.sub(name, 3)] then
        negated = true
        name = string.sub(name, 3)
    end

    local arg = string.match(text, "^[%a_]+%s*:%s*(.-)%s*$")

    table.insert(group.Conditions, AddToken(scan, {
        Kind = "condition",
        S = s,
        E = e,
        Text = text,
        Name = name,
        Negated = negated,
        Arg = arg,
        Known = Conditions[name] ~= nil,
        Group = group,
    }))
end

local function ParseGroup(scan, clause, code, s, e, closed)
    local group = { S = s, E = e, Inner = string.sub(code, s + 1, closed and e - 1 or e), Closed = closed, Conditions = {}, Clause = clause }
    local partStart = s + 1
    local innerEnd = closed and e - 1 or e

    for i = s + 1, innerEnd + 1 do
        if i > innerEnd or string.sub(code, i, i) == "," then
            ParseCondition(scan, group, code, partStart, i - 1)
            partStart = i + 1
        end
    end

    table.insert(clause.Groups, group)
end

local function AddName(scan, clause, code, s, e)
    s, e = TrimRange(code, s, e)
    if string.sub(code, s, s) == "!" then
        s = s + 1
    end
    if s <= e then
        table.insert(clause.Names, AddToken(scan, { Kind = "name", S = s, E = e, Text = string.sub(code, s, e), Clause = clause }))
    end
end

local function ParseNames(scan, line, clause, code)
    local s, e = clause.ValueS, clause.ValueE
    if not s or s > e then
        return
    end

    if SingleNameCommands[line.Command] or line.Kind == "show" then
        AddName(scan, clause, code, s, e)
    elseif ListNameCommands[line.Command] then
        -- castsequence can start with "reset=..." before the list
        local reset = string.match(string.sub(code, s, e), "^reset=%S*%s*")
        if reset then
            s = s + #reset
        end
        local partStart = s
        for i = s, e + 1 do
            if i > e or string.sub(code, i, i) == "," then
                AddName(scan, clause, code, partStart, i - 1)
                partStart = i + 1
            end
        end
    end
end

local function ParseBody(scan, line, code, s, e)
    local i = s

    while true do
        while i <= e and string.find(string.sub(code, i, i), "[ \t]") do i = i + 1 end

        local clause = { S = i, Groups = {}, Names = {}, Line = line }

        while i <= e and string.sub(code, i, i) == "[" do
            local close = string.find(code, "]", i + 1, true)
            if close and close <= e then
                ParseGroup(scan, clause, code, i, close, true)
                i = close + 1
            else
                ParseGroup(scan, clause, code, i, e, false)
                i = e + 1
            end
            while i <= e and string.find(string.sub(code, i, i), "[ \t]") do i = i + 1 end
        end

        local semicolon = string.find(code, ";", i, true)
        if semicolon and semicolon > e then
            semicolon = nil
        end

        clause.E = semicolon and semicolon - 1 or e
        clause.ValueS, clause.ValueE = TrimRange(code, i, clause.E)
        clause.Value = string.sub(code, clause.ValueS, clause.ValueE)
        ParseNames(scan, line, clause, code)
        table.insert(line.Clauses, clause)

        if not semicolon then
            break
        end
        i = semicolon + 1
    end
end

local function ParseLine(scan, code, s, e)
    local line = { S = s, E = e, Clauses = {} }
    table.insert(scan.Lines, line)

    local i = s
    while i <= e and string.find(string.sub(code, i, i), "[ \t]") do i = i + 1 end

    local first = string.sub(code, i, i)

    if first == "#" then
        local word = string.match(code, "^#(%a+)", i) or ""
        local lower = string.lower(word)
        if lower == "showtooltip" or lower == "show" then
            line.Kind = "show"
            AddToken(scan, { Kind = "directive", S = i, E = i + #word, Name = lower, Line = line })
            ParseBody(scan, line, code, i + #word + 1, e)
        else
            line.Kind = "comment"
        end
    elseif first == "/" then
        local word = string.match(code, "^/([%w_]+)", i)
        if not word then
            line.Kind = "other"
            return
        end

        line.Kind = "command"
        line.Command = string.lower(word)
        AddToken(scan, { Kind = "command", S = i, E = i + #word, Name = line.Command, Line = line })

        if OptionCommands[line.Command] then
            -- Same as the icon logic: a # part way through a line starts a comment
            local hash = string.find(code, "#", i, true)
            local bodyEnd = (hash and hash <= e) and hash - 1 or e
            ParseBody(scan, line, code, i + #word + 1, bodyEnd)
        end
    else
        line.Kind = "other"
    end
end

-- Test a set of conditions with the game's own logic. nil when it can't be worked out.
local function Test(conditionText)
    if not SecureCmdOptionParse then
        return nil
    end
    local ok, result = pcall(SecureCmdOptionParse, "[" .. conditionText .. "] TRUE")
    if not ok then
        return nil
    end
    return result == "TRUE"
end

local function DimRange(dim, s, e)
    for i = s, e do
        dim[i] = true
    end
end

MegaMacroInsights = {}

function MegaMacroInsights.Scan(code)
    local scan = { Code = code, Lines = {}, Tokens = {} }
    local s = 1
    local length = #code

    while s <= length + 1 do
        local newline = string.find(code, "\n", s, true)
        local e = newline and newline - 1 or length
        ParseLine(scan, code, s, e)
        if not newline then
            break
        end
        s = newline + 1
    end

    return scan
end

-- Fills in Passes/Used flags on the scan and returns the characters to fade, plus a
-- signature that changes whenever the result does.
function MegaMacroInsights.Evaluate(scan)
    local dim = {}
    local signature = {}
    local stopped = false

    for _, line in ipairs(scan.Lines) do
        line.Stopped = stopped

        if stopped then
            if line.Kind ~= "comment" then
                DimRange(dim, line.S, line.E)
            end
        elseif #line.Clauses > 0 then
            local winner
            local unknown = false

            for _, clause in ipairs(line.Clauses) do
                local clausePasses = #clause.Groups == 0

                for _, group in ipairs(clause.Groups) do
                    group.Passes = nil
                    if group.Closed then
                        group.Passes = Test(group.Inner)
                    end
                    if group.Passes == nil then
                        unknown = true
                    end
                    clausePasses = clausePasses or group.Passes == true

                    local targetText = group.Target and (group.Target.Text .. ",") or ""
                    for _, condition in ipairs(group.Conditions) do
                        condition.Passes = nil
                        if group.Closed then
                            condition.Passes = Test(targetText .. condition.Text)
                        end
                    end
                end

                clause.Passes = clausePasses
                clause.Used = false
                if clausePasses and not winner then
                    winner = clause
                    clause.Used = true
                end
            end

            line.Winner = winner
            line.Unknown = unknown
            -- "/cast [x] Wrath;" ends in an empty option that always matches but casts nothing
            line.Empty = winner ~= nil and winner.Value == ""
                and (SingleNameCommands[line.Command] or ListNameCommands[line.Command]) or false

            if not unknown then
                if not winner or line.Empty then
                    DimRange(dim, line.S, line.E)
                else
                    for index, clause in ipairs(line.Clauses) do
                        if clause ~= winner then
                            -- include the ; that ends it
                            local e = index < #line.Clauses and clause.E + 1 or clause.E
                            DimRange(dim, clause.S, e)
                        else
                            for _, group in ipairs(clause.Groups) do
                                if not group.Passes then
                                    DimRange(dim, group.S, group.E)
                                end
                            end
                        end
                    end
                end

                if winner and line.Command == "stopmacro" then
                    stopped = true
                end
            end

            local state = unknown and "?" or "0"
            if winner then
                for index, clause in ipairs(line.Clauses) do
                    if clause == winner then
                        state = tostring(index)
                        for groupIndex, group in ipairs(clause.Groups) do
                            state = state .. (group.Passes and "+" or "-") .. groupIndex
                        end
                    end
                end
            end
            table.insert(signature, state)
        end

        table.insert(signature, stopped and "s" or "")
    end

    return dim, table.concat(signature, ",")
end

function MegaMacroInsights.TokenAt(scan, index)
    if not scan or not index then
        return nil
    end
    for _, token in ipairs(scan.Tokens) do
        if index >= token.S and index <= token.E then
            return token
        end
    end
end
