function ShowToolTipForMegaMacro(macroId)
    -- 12.0 Safety: Ensure the tooltip exists
    if not GameTooltip then return end

    GameTooltip:Hide()
    
    -- 12.0 Requirement: Tooltips must have an owner set before content is added.
    -- "ANCHOR_CURSOR" puts it near the mouse, which is standard for macros.
    -- You can also use "ANCHOR_RIGHT" if you prefer the bottom-right corner.
    GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")

    local data = MegaMacroIconEvaluator.GetCachedData(macroId)

    if data then
        if data.Type == "spell" then
            -- 12.0: SetSpellByID expects the numeric SpellID
            GameTooltip:SetSpellByID(data.Id)
        elseif data.Type == "item" then
            -- 12.0 Fix: SetInventoryItemByID is deprecated for general item links.
            -- Use SetItemByID instead.
            GameTooltip:SetItemByID(data.Id)
        elseif data.Type == "equipment set" then
            GameTooltip:SetEquipmentSet(data.Name)
        else
            -- Fallback for text-only macros
            local megaMacro = MegaMacro.GetById(macroId)
            if megaMacro and megaMacro.DisplayName then
                GameTooltip:SetText(megaMacro.DisplayName, 1, 1, 1)
            end
        end

        GameTooltip:Show()
    else
        -- If data is missing (e.g. during loading), try to show the name at least
        local megaMacro = MegaMacro.GetById(macroId)
        if megaMacro and megaMacro.DisplayName then
            GameTooltip:SetText(megaMacro.DisplayName, 1, 1, 1)
            GameTooltip:Show()
        end
    end
end