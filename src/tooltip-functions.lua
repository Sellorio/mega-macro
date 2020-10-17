function ShowToolTipForMegaMacro(macroId)
	GameTooltip:Hide()
	GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)

	local data = MegaMacroIconEvaluator.GetCachedData(macroId)

	if data then
		if data.Type == "spell" then
			GameTooltip:SetSpellByID(data.Id)
			-- GameTooltip:SetToyByItemID(itemId)
		elseif data.Type == "item" then
			GameTooltip:SetItemByID(data.Id)
		elseif data.Type == "equipment set" then
			GameTooltip:SetEquipmentSet(data.Name)
		else
			local megaMacro = MegaMacro.GetById(macroId)
			GameTooltip:SetText(megaMacro.DisplayName, 1, 1, 1)
		end

		GameTooltip:Show()
	end
end